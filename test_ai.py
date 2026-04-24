import os
from google import genai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Verify the .env is being loaded correctly
api_key = os.environ.get("GEMINI_API_KEY")
print(f"Loaded API Key starting with: {api_key[:10] if api_key else 'None'}")

def test_gemini():
    try:
        # Initialize client with explicit API key loaded from .env
        client = genai.Client(api_key=api_key)
        
        prompt = "Identify a resource needed in a city based on a broken water pipe"
        print(f"Sending prompt: '{prompt}' to gemini-3-flash-preview...")
        
        response = client.models.generate_content(
            model='gemini-3-flash-preview', 
            contents=prompt
        )
        print("\nResponse from Gemini:")
        print(response.text)
    except Exception as e:
        print(f"Error testing Gemini API: {e}")

if __name__ == "__main__":
    test_gemini()
