import requests
import json
from datetime import datetime

def test_prediction():
    url = "http://localhost:8001/predict"
    
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
    
    print("Testing prediction endpoint...")
    print("Sending data:", json.dumps(data, indent=2))
    
    try:
        response = requests.post(
            url,
            json=data,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        print(f"Status Code: {response.status_code}")
        print("Response:", json.dumps(response.json(), indent=2))
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    test_prediction()
