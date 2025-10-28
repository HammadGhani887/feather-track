import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8001"

def test_health_check():
    print("\n=== Testing health check ===")
    try:
        response = requests.get(f"{BASE_URL}/")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return True
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_prediction():
    print("\n=== Testing prediction ===")
    # Get current date components
    now = datetime.now()
    
    data = {
        "hour": now.hour,
        "feed_consumption": 50.5,
        "temperature": 25.0,
        "humidity": 60.0,
        "hens": 100,
        "day_of_year": now.timetuple().tm_yday,
        "month": now.month,
        "day_of_week": now.weekday() + 1  # 1-7 for Monday-Sunday
    }
    
    print("Sending data:", json.dumps(data, indent=2))
    
    try:
        response = requests.post(
            f"{BASE_URL}/predict",
            json=data,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        print(f"Status: {response.status_code}")
        print("Response:", json.dumps(response.json(), indent=2))
        return True
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("Starting API tests...")
    print(f"Testing against: {BASE_URL}")
    
    if test_health_check():
        test_prediction()
