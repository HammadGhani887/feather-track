import requests

def test_connection():
    try:
        response = requests.get('http://localhost:8001/', timeout=5)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    test_connection()
