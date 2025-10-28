import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import pickle
import os

def load_and_preprocess_data(filepath):
    """Load and preprocess the dataset."""
    # Load the dataset
    df = pd.read_csv(filepath)
    
    # Convert Date to datetime and extract useful features
    df['Date'] = pd.to_datetime(df['Date'])
    df['DayOfYear'] = df['Date'].dt.dayofyear
    df['Month'] = df['Date'].dt.month
    df['DayOfWeek'] = df['Date'].dt.dayofweek
    
    # Features to use for prediction
    features = ['Hour', 'Feed_Consumption_kg', 'Temperature_C', 'Humidity_%', 
               'Hens', 'DayOfYear', 'Month', 'DayOfWeek']
    
    # Target variable
    target = 'Eggs'
    
    X = df[features]
    y = df[target]
    
    return X, y, df

def train_random_forest(X, y):
    """Train a Random Forest model and return it."""
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Initialize and train the model
    model = RandomForestRegressor(
        n_estimators=100,
        random_state=42,
        n_jobs=-1,
        max_depth=10,
        min_samples_split=5
    )
    
    model.fit(X_train, y_train)
    
    # Make predictions
    y_pred = model.predict(X_test)
    
    # Calculate metrics
    mse = mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    
    print(f"Model trained successfully!")
    print(f"Mean Squared Error: {mse:.2f}")
    print(f"R² Score: {r2:.4f}")
    
    return model, X_test, y_test

def save_model(model, filename='egg_production_model.pkl'):
    """Save the trained model to a pickle file."""
    with open(filename, 'wb') as file:
        pickle.dump(model, file)
    print(f"Model saved as {filename}")

if __name__ == "__main__":
    # File path
    data_file = 'hourly_poultry_data.csv'
    
    # Check if file exists
    if not os.path.exists(data_file):
        print(f"Error: {data_file} not found in the current directory.")
        exit(1)
    
    # Load and preprocess data
    print("Loading and preprocessing data...")
    X, y, _ = load_and_preprocess_data(data_file)
    
    # Train the model
    print("Training Random Forest model...")
    model, X_test, y_test = train_random_forest(X, y)
    
    # Save the model
    save_model(model)
    
    # Print feature importances
    feature_importances = pd.Series(
        model.feature_importances_, 
        index=X.columns
    ).sort_values(ascending=False)
    
    print("\nFeature Importances:")
    print(feature_importances)
