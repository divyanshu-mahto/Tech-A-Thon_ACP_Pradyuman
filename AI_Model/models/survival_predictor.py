import joblib
import numpy as np
import random

# Load the saved model
try:
    voting_model = joblib.load('D:\\VIT\\SEMESTER 5\\AI_lab\\AI_Hack\\models\\voting_model.pkl')
except FileNotFoundError:
    print("Model file not found. Please check the path and try again.")
    exit()

def calculate_survival_probability(age, cabin_no, distance):
    # Determine `pclass` based on cabin_no
    pclass = random.choice([1, 2, 3])
    if (distance == 0):
        return 1.00

    # Prepare input features in the expected order
    passenger_features = np.array([[pclass, 0 if age < 18 else 1, age, 1, 3, cabin_no, distance]])

    # Predict survival probabilities
    try:
        survival_probabilities = voting_model.predict_proba(passenger_features)
        survival_probability = survival_probabilities[0][1]  # Probability of survival
    except Exception as e:
        print(f"Error in model prediction: {e}")
        return None

    return survival_probability

# Example usage with user input
try:
    age_input = float(input("Enter passenger's age: "))
    cabin_no_input = int(input("Enter passenger's cabin number: "))
    distance_input = float(input("Enter distance from lifeboat: "))

    survival_probability = calculate_survival_probability(age_input, cabin_no_input, distance_input)
    if survival_probability is not None:
        print(f"The estimated probability of survival is: {survival_probability:.2f}")
except ValueError:
    print("Invalid input. Please enter numeric values for age, cabin number, speed, and distance.")