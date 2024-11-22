extends CharacterBody2D

@export var move_speed: float = 100
@export var ai_request_interval: float = 0.2
@export var request_timeout: float = 10.0
@export var max_retry_attempts: int = 3
@export var game_duration: float = 60.0  # Game duration in seconds

@export var sex: int = 0  # 0 for male, 1 for female
@export var age: int = 40
@export var pclass: int = 1  # 1, 2, or 3
@export var sibsp: int = 1  # Number of siblings/spouses aboard
@export var parch: int = 5  # Number of parents/children aboard
@export var fare: float = 80.0  # Fare amount, should be <100

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var http_request = HTTPRequest.new()
@onready var survival_label = get_node("/root/GameLevel/HUD/Survival")
@onready var timer_label = get_node("/root/GameLevel/HUD/Timer")

var last_direction = Vector2.ZERO
var time_since_last_request: float = 0.0
var is_request_pending: bool = false
var request_queue = []
const MAX_QUEUE_SIZE = 3
var retry_count = 0
var server_url = "http://127.0.0.1:5000/predict"
var last_survival_value = "0.0"
var time_remaining: float
var is_game_active: bool = true
var origin_position = Vector2(100, 100)  # Assuming this as the starting point of the character

func _ready():
	add_child(http_request)
	http_request.connect("request_completed", _on_request_completed)
	
	http_request.timeout = request_timeout
	http_request.max_redirects = 2
	
	# Initialize timer and labels
	time_remaining = game_duration
	update_survival_probability(0.0)
	update_timer_display()
	
	# Test connection on startup
	test_server_connection()

func update_timer_display():
	var minutes = floor(time_remaining / 60)
	var seconds = fmod(time_remaining, 60)
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func update_survival_probability(value: float):
	last_survival_value = "%.3f" % value
	survival_label.text = "Survival Probability: " + str(float(last_survival_value) * 100) + "%"


func test_server_connection():
	var headers = ["Content-Type: application/json"]
	var test_data = JSON.stringify({"x": 0, "y": 0})
	
	var error = http_request.request(
		server_url,
		headers,
		HTTPClient.METHOD_POST,
		test_data
	)
	
	if error != OK:
		survival_label.text = "Survival Probability: " + last_survival_value + "%"

func game_over():
	is_game_active = false
	
	# Create game over popup
	var popup = AcceptDialog.new()
	add_child(popup)
	
	# Configure popup
	popup.title = "Game Over!"
	popup.dialog_text = "Time's up!\nFinal Survival Probability: " + last_survival_value + "%"
	popup.get_ok_button().text = "Restart"
	
	# Connect to the popup's confirmed signal
	popup.confirmed.connect(restart_game)
	
	# Show the popup
	popup.popup_centered()
	
	# Stop movement
	velocity = Vector2.ZERO
	state_machine.travel("idle")

func restart_game():
	# Reset timer
	time_remaining = game_duration
	is_game_active = true
	
	# Reset position (adjust coordinates as needed)
	position = Vector2(100, 100)
	
	# Reset survival probability
	update_survival_probability(0.0)

func _physics_process(delta: float) -> void:
	if not is_game_active:
		return
		
	# Update timer
	time_remaining -= delta
	update_timer_display()
	
	# Check for game over
	if time_remaining <= 0:
		time_remaining = 0
		update_timer_display()
		game_over()
		return
	
	# Handle movement
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	velocity = input_direction * move_speed
	move_and_slide()
	
	if input_direction != Vector2.ZERO:
		last_direction = input_direction
	
	update_animation_parameters(input_direction)
	pick_new_state()
	
	time_since_last_request += delta
	if time_since_last_request >= ai_request_interval:
		queue_position_update()
		time_since_last_request = 0.0
		process_queue()

func update_animation_parameters(move_input: Vector2):
	if move_input != Vector2.ZERO:
		animation_tree.set("parameters/walk/blend_position", move_input)
	else:
		animation_tree.set("parameters/idle/blend_position", last_direction)

func pick_new_state():
	if velocity != Vector2.ZERO:
		state_machine.travel("walk")
	else:
		state_machine.travel("idle")

func queue_position_update():
	var current_position = position
	var custom_origin = Vector2(149.2,77.5)
	
	var distance = custom_origin.distance_to(current_position)
	
	var position_data = {
		"sex": sex,
		"age": age,
		"pclass": pclass,
		"sibsp": sibsp,
		"parch": parch,
		"fare": fare,
		"distance": distance
	}
	
	print("distance: ",distance)
	print("x: ",position.x, "y: ",position.y)
	
	if request_queue.size() < MAX_QUEUE_SIZE:
		request_queue.append(position_data)

func process_queue():
	if not is_request_pending and request_queue.size() > 0:
		send_position_to_ai(request_queue.pop_front())

func send_position_to_ai(position_data: Dictionary):
	if is_request_pending:
		return
	
	var json = JSON.stringify(position_data)
	var headers = [
		"Content-Type: application/json",
		"Connection: keep-alive"
	]
	
	var error = http_request.request(
		server_url,
		headers,
		HTTPClient.METHOD_POST,
		json
	)
	
	if error != OK:
		print("HTTP Request Error: ", error)
		handle_request_error(error, position_data)

func handle_request_error(error_code: int, position_data: Dictionary):
	print("Connection error occurred. Error code: ", error_code)
	
	if retry_count < max_retry_attempts:
		retry_count += 1
		request_queue.push_front(position_data)
		await get_tree().create_timer(1.0).timeout
		process_queue()
	else:
		print("Max retry attempts reached. Please check server connection.")
		retry_count = 0
		is_request_pending = false

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	is_request_pending = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		retry_count = 0
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("result"):
			var prediction = float(json.result)
			update_survival_probability(prediction)
	else:
		if body.size() > 0:
			print("Error details: ", body.get_string_from_utf8())
	
	if request_queue.size() > 0:
		send_position_to_ai(request_queue.pop_front())
