# feather_track_web

Predict hourly egg production based on farm conditions with a Flutter Web frontend and a FastAPI backend serving a trained ML model.

## Overview

This project provides a simple interface for farm managers to input parameters (hour, feed consumption, temperature, humidity, hens, etc.) and receive a predicted number of eggs. The prediction is powered by a Random Forest model serialized with joblib and exposed via a FastAPI service.

## Features
- Flutter Web UI for inputting parameters and viewing predictions
- FastAPI backend with CORS enabled
- Trained Random Forest regression model (`egg_production_model.pkl`)
- Simple retraining script for updating the model

## Tech Stack
- Frontend: Flutter (Web)
- Backend: Python, FastAPI, Uvicorn
- ML/DS: scikit-learn, pandas, numpy, joblib

## Project Structure
- `lib/` Flutter app source
- `web/` Flutter web assets
- `model_api.py` FastAPI server exposing `/` and `/predict`
- `egg_production_model.pkl` Trained model file (not recommended to commit for large size)
- `train_egg_prediction_model.py` Script to train and generate the model
- `requirements.txt` Python dependencies
- `pubspec.yaml` Flutter dependencies and assets

## Prerequisites
- Windows/macOS/Linux
- Flutter SDK installed and configured (for Web)
- Python 3.9+ installed

---

## Installation & Setup

### 1) Backend (FastAPI)

Open a terminal in the project root and create/activate a virtual environment, then install dependencies.

Windows PowerShell:
```powershell
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Make sure the trained model file exists in the project root:
- Expected path: `egg_production_model.pkl`
- If you don't have it yet, see “Retrain the Model” below.

Run the API server:
```powershell
python model_api.py --host 0.0.0.0 --port 8000
```

The API should be available at:
- http://localhost:8000

### 2) Frontend (Flutter Web)

Install Flutter dependencies and run in Chrome:
```powershell
flutter pub get
flutter run -d chrome
```

Flutter will open the web app in your browser. Ensure the backend is also running so the app can fetch predictions.

---

## API Documentation

### Health Check
- `GET /`
```json
{
  "status": "healthy",
  "message": "Egg Production Prediction API is running"
}
```

### Predict Eggs
- `POST /predict`

Request body (JSON):
```json
{
  "hour": 10,
  "feed_consumption": 12.5,
  "temperature": 26.3,
  "humidity": 60.2,
  "hens": 1500
}
```

Optional fields (will default to current date if omitted): `day_of_year`, `month`, `day_of_week`.

Sample cURL:
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "hour": 10,
    "feed_consumption": 12.5,
    "temperature": 26.3,
    "humidity": 60.2,
    "hens": 1500
  }'
```

Sample response:
```json
{
  "status": "success",
  "prediction": 123.45,
  "features": {
    "Hour": [10],
    "Feed_Consumption_kg": [12.5],
    "Temperature_C": [26.3],
    "Humidity_%": [60.2],
    "Hens": [1500],
    "DayOfYear": [300],
    "Month": [10],
    "DayOfWeek": [2]
  }
}
```

---

## Retrain the Model

If you need to regenerate `egg_production_model.pkl`:

```powershell
# Ensure venv is activated
python train_egg_prediction_model.py
```

This will train and produce a new `egg_production_model.pkl` in the project root. Adjust the script as needed for your data.

---

## Build for Web (Release)

```powershell
flutter build web --release
```

The build output will be in `build/web/`. You can deploy these static files to any static hosting provider.

---

## Troubleshooting
- Make sure the backend is running on `http://localhost:8000` before using the web UI.
- Port already in use? Change `--port` when starting `model_api.py` and update the frontend configuration if needed.
- If you see CORS issues, confirm the FastAPI server is reachable from the browser and that CORS is enabled (it is in `model_api.py`).

---

## License

Choose a license that suits your needs (MIT recommended for portfolios).
