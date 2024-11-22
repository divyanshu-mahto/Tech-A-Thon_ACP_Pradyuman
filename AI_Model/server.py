from flask import Flask, request, jsonify
import joblib
import numpy as np

app = Flask(__name__)

# Load the saved model
try:
    voting_model = joblib.load('D:\\VIT\\SEMESTER 5\\AI_lab\\AI_Hack\\models\\voting_model.pkl')
except FileNotFoundError:
    print("Model file not found. Please check the path and try again.")
    exit()

# Function to calculate survival probability
def calculate_survival_probability(pclass, sex, age, sibsp, parch, fare, distance):
    # If the distance is 0, assume 100% survival
    if distance <= 38:
        return 1.00

    # Prepare input features in the expected order
    passenger_features = np.array([[pclass, sex, age, sibsp, parch, fare, distance]])

    # Predict survival probabilities
    try:
        survival_probabilities = voting_model.predict_proba(passenger_features)
        survival_probability = survival_probabilities[0][1]  # Probability of survival
    except Exception as e:
        print(f"Error in model prediction: {e}")
        return None

    return survival_probability

# API endpoint to get survival probability
@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get data from POST request
        data = request.get_json()
        pclass = data.get("pclass")
        sex = data.get("sex")
        age = data.get("age")
        sibsp = data.get("sibsp")
        parch = data.get("parch")
        fare = data.get("fare")
        distance = data.get("distance")

        # Validate if any required parameter is missing
        if None in [pclass, sex, age, sibsp, parch, fare, distance]:
            return jsonify({"error": "Missing input data"}), 400

        # Calculate the survival probability
        survival_probability = calculate_survival_probability(pclass, sex, age, sibsp, parch, fare, distance)

        if survival_probability is not None:
            return jsonify({"result": round(survival_probability, 2)})
        else:
            return jsonify({"error": "Error in predicting survival probability"}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(debug=True)
