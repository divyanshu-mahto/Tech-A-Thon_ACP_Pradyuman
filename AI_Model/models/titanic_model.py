import pandas as pd
import joblib
from sklearn import svm
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.impute import SimpleImputer
from sklearn.neighbors import KNeighborsClassifier
from sklearn.ensemble import VotingClassifier
from sklearn.metrics import confusion_matrix, accuracy_score, classification_report

# Load the dataset
data = pd.read_csv('D:\\VIT\\SEMESTER 5\\AI_lab\\AI_Hack\\data\\Generated_Titanic_Dataset.csv')

# Preprocess data
data['Sex'] = data['Sex'].map({'male': 0, 'female': 1})
data['Embarked'] = data['Embarked'].map({'C': 0, 'Q': 1, 'S': 2})

# Define features and target variable
X = data[['Pclass', 'Sex', 'Age', 'SibSp', 'Parch', 'Fare', 'MinDistanceToLifeboat']]
imputer = SimpleImputer(strategy='mean')
X = imputer.fit_transform(X)
y = data['Survived']


# Initialize individual models
model_svm = svm.SVC(kernel='linear', probability=True)
model_logistic = LogisticRegression()
model_tree = DecisionTreeClassifier()
model_knn = KNeighborsClassifier()

# Combine models using Voting Classifier
voting_model = VotingClassifier(estimators=[
    ('svm', model_svm),
    ('logistic', model_logistic),
    ('tree', model_tree),
    ('knn', model_knn)
], voting='soft')  # Use 'soft' voting for probability-based voting

# Train the ensemble model using 100% of the data
voting_model.fit(X, y)

# Make predictions on the same dataset
y_pred = voting_model.predict(X)

# Evaluate the ensemble model
conf_matrix = confusion_matrix(y, y_pred)
accuracy = accuracy_score(y, y_pred)
class_report = classification_report(y, y_pred)

print("Confusion Matrix:")
print(conf_matrix)
print("\nAccuracy:", accuracy)
print("\nClassification Report:")
print(class_report)

joblib.dump(voting_model, 'D:\\VIT\\SEMESTER 5\\AI_lab\\AI_Hack\\models\\voting_model.pkl')
