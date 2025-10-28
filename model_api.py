from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import joblib
import logging
from datetime import datetime
from typing import Optional
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI
app = FastAPI(
    title="Egg Production Prediction API",
    description="API for predicting egg production using Random Forest model",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the trained model
model = joblib.load('egg_production_model.pkl')

# Define request model
class PredictionRequest(BaseModel):
    hour: int
    feed_consumption: float
    temperature: float
    humidity: float
    hens: int
    day_of_year: Optional[int] = None
    month: Optional[int] = None
    day_of_week: Optional[int] = None

# Health check endpoint
@app.get("/")
async def health_check():
    return {"status": "healthy", "message": "Egg Production Prediction API is running"}

# Add middleware for request logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Request: {request.method} {request.url}")
    logger.info(f"Headers: {request.headers}")
    try:
        body = await request.body()
        logger.info(f"Body: {body.decode()}")
    except Exception as e:
        logger.warning(f"Could not log request body: {e}")
    
    response = await call_next(request)
    return response

# Prediction endpoint
@app.post("/predict")
async def predict_eggs(request: PredictionRequest):
    logger.info(f"Received prediction request: {request.dict()}")
    try:
        # Get current date components if not provided
        current_date = datetime.now()
        day_of_year = request.day_of_year or current_date.timetuple().tm_yday
        month = request.month or current_date.month
        day_of_week = request.day_of_week or current_date.weekday()
        
        # Create feature dictionary
        features = {
            'Hour': [request.hour],
            'Feed_Consumption_kg': [request.feed_consumption],
            'Temperature_C': [request.temperature],
            'Humidity_%': [request.humidity],
            'Hens': [request.hens],
            'DayOfYear': [day_of_year],
            'Month': [month],
            'DayOfWeek': [day_of_week]
        }
        
        # Create DataFrame
        df = pd.DataFrame(features)
        
        # Make prediction
        prediction = model.predict(df)
        
        return {
            "status": "success",
            "prediction": float(prediction[0]),
            "features": features
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Run the API
if __name__ == "__main__":
    import uvicorn
    import argparse
    
    parser = argparse.ArgumentParser(description='Run the FastAPI server')
    parser.add_argument('--port', type=int, default=8000, help='Port to run the server on')
    parser.add_argument('--host', type=str, default='0.0.0.0', help='Host to bind the server to')
    args = parser.parse_args()
    
    print(f"Starting server on {args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port)
