import os
import json
import requests
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from dotenv import load_dotenv
from logic.arbitrage import check_detour_efficiency


os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "serviceAccountKey.json"
# Initialize Firebase Admin with the key file
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# Load environment variables from .env file
load_dotenv()

SIMULATION_MODE = True

class UrbanNeedResponse(BaseModel):
    item: str = Field(
        description="The detected need. Must be one of: 'Clean Water', 'Medical Kits', 'Wi-Fi', or 'None'."
    )
    urgency: int = Field(
        description="Urgency of the need on a scale from 1 to 10. 0 if none."
    )
    context: str = Field(
        description="Short description explaining the context of the need."
    )

def get_urban_needs(image_url: str) -> dict:
    """
    Uses Gemini 3.1 Pro to perform multimodal analysis on a street image
    and detect if there is a need for Clean Water, Medical Kits, or Wi-Fi.
    """
    if SIMULATION_MODE:
        return {
            "item": "Clean Water Kit",
            "urgency": 9,
            "lat": 12.923,
            "lng": 77.498,
            "context": "Simulated leak near RVCE"
        }

    # 1. Fetch the image content
    try:
        response = requests.get(image_url)
        response.raise_for_status()
        image_data = response.content
        
        mime_type = response.headers.get('Content-Type', 'image/jpeg')
        if not mime_type.startswith('image/'):
            mime_type = 'image/jpeg'
            
    except Exception as e:
        return {
            "item": "Error",
            "urgency": 0,
            "context": f"Failed to download image: {str(e)}"
        }

    # 2. Initialize the GenAI client with explicit API key loaded from .env
    try:
        api_key = os.environ.get('GEMINI_API_KEY')
        client = genai.Client(api_key=api_key)
    except Exception as e:
        return {
            "item": "Error",
            "urgency": 0,
            "context": f"Failed to initialize Gemini client: {str(e)}"
        }

    # 3. Define the prompt
    prompt = (
        "Analyze this street image and determine if there is a visible need for "
        "Clean Water, Medical Kits, or Wi-Fi based on the objects, people, or signs in the scene. "
        "Provide the most critical need identified. If multiple exist, pick the most urgent one. "
        "If none exist, return 'None' for item."
    )

    # 4. Call Gemini model
    try:
        response = client.models.generate_content(
            model='gemini-3.1-pro',
            contents=[
                types.Part.from_bytes(data=image_data, mime_type=mime_type),
                prompt
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=UrbanNeedResponse,
                temperature=0.2,
            ),
        )
        
        return json.loads(response.text)
        
    except Exception as e:
        return {
            "item": "Error",
            "urgency": 0,
            "context": f"Gemini API error: {str(e)}"
        }

def upload_mission_to_firestore(data: dict, lat: float = None, lng: float = None) -> str:
    """
    Takes the JSON data from Gemini and creates a new document in the 
    'active_missions' Firestore collection.
    """
    # Use explicit lat/lng if provided, else check 'data' payload, else default to Kengeri
    final_lat = lat if lat is not None else data.get("lat", 12.9069)
    final_lng = lng if lng is not None else data.get("lng", 77.4855)

    try:
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
            
        db = firestore.client()
        
        mission_payload = {
            "item": data.get("item", "None"),
            "urgency": data.get("urgency", 0),
            "context": data.get("context", ""),
            "lat": final_lat,
            "lng": final_lng,
            "status": "pending"
        }
        
        doc_ref = db.collection('active_missions').document()
        doc_ref.set(mission_payload)
        
        return doc_ref.id
    except Exception as e:
        print(f"Failed to upload to Firestore: {e}")
        return None

if __name__ == "__main__":
    if SIMULATION_MODE:
        print("Running in SIMULATION MODE...")
        mock_data = get_urban_needs("dummy_url")
        print(f"Generated Mock Data: {json.dumps(mock_data, indent=2)}")
        
        # Check detour efficiency
        driver_start = (12.9120, 77.4800) # Mock driver start location
        driver_end = (12.9300, 77.5000)   # Mock driver end location
        mission_loc = (mock_data.get("lat", 12.9069), mock_data.get("lng", 77.4855))
        
        if check_detour_efficiency(driver_start, driver_end, mission_loc):
            print("Detour is Efficient! Uploading to the app...")
            doc_id = upload_mission_to_firestore(mock_data)
            if doc_id:
                print(f"Successfully uploaded simulated mission to Firestore! Document ID: {doc_id}")
            else:
                print("Failed to upload simulated mission.")
        else:
            print("Detour is too long (adds >= 20%). Mission skipped.")
    else:
        pass
