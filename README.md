🚑 PulseRoute: Real-Time Crisis Logistics & Dispatch System
(Optional: Replace this link with a screenshot of your app!)

PulseRoute is a real-time, cross-platform logistics ecosystem designed to bridge the gap between crisis detection and on-the-ground resource delivery. Built for the Google Solution Challenge, it empowers dispatchers to instantly deploy emergency resources (like clean water kits) to critical hotspots while gamifying the delivery process for volunteer drivers.

📖 Table of Contents
About the Project

Key Features

Technology Stack

System Architecture

Getting Started (Local Development)

Environment Variables

Deployment

Future Roadmap

🌍 About the Project
During natural disasters or localized crises, the "last mile" of resource delivery is often the most chaotic. PulseRoute solves this by providing a unified, real-time dashboard.

For Dispatchers (Admin Panel): A bird's-eye view to deploy targeted missions with specific context and urgency metrics.

For Drivers (Driver App): An intuitive, hands-free navigation UI that guides them directly to the hotspot, rewarding them with "Pulse Tokens" for their verified impact.

✨ Key Features
Real-time Mission Assignment: Admins can instantly deploy crisis missions to the exact location of need without communication delays.

Live Map-Based Tracking: Drivers receive road-snapped routing while the system tracks their live GPS coordinates for full visibility.

Accept & Complete Delivery System: A streamlined, two-tap workflow for drivers to claim pending missions and confirm successful resource drops.

Token-Based Reward System: Drivers earn gamified "Pulse Tokens" for every completed delivery, quantifying their positive community impact.

Mission History Tracking: A dedicated log of all resolved hotspots, providing a clear audit trail for data-driven analysis of past relief efforts.

Firebase Cloud Sync: Robust backend architecture ensuring the Admin dashboard and Driver apps update instantly across all devices.

💻 Technology Stack
PulseRoute heavily leverages the Google developer ecosystem for maximum scalability and real-time performance.

Frontend:

Flutter - Cross-platform UI framework

Geolocator - Real-time GPS coordinate tracking

Backend & Database:

Firebase Cloud Firestore - Real-time NoSQL database

Firebase Core - Cloud infrastructure

Mapping & Routing:

Google Maps Platform (Maps_flutter) - Interactive map UI

Google Directions API (flutter_polyline_points) - Road-snapped pathing and detour logic

Deployment:

Firebase Hosting - Fast, secure web deployment

⚙️ Getting Started (Local Development)
To run this project locally on your machine, follow these steps.

Prerequisites
Install Flutter SDK.

Install Node.js (for Firebase CLI).

Set up a Firebase Project and a Google Cloud Project (with Maps SDK and Directions API enabled).

Installation
Clone the repository:

Bash
git clone https://github.com/your-username/PulseRoute.git
cd PulseRoute
Install dependencies:

Bash
flutter pub get
Setup Environment Variables (CRITICAL):
This project uses flutter_dotenv to protect API keys. You must create a .env file in the root directory.

Bash
touch .env
Add your Google Maps API Key to the .env file:

Code snippet
MAPS_API_KEY=your_actual_google_maps_api_key_here
Run the App (Web Chrome):

Bash
flutter run -d chrome
Note: To view the Admin Panel, navigate to http://localhost:[port]/#/admin in your browser.

🚀 Deployment
This project is configured for continuous deployment via Firebase Hosting.

To deploy a new build to the web:

Bash
# 1. Compile the Flutter code to Web
flutter build web

# 2. Deploy only the hosting files to Firebase
firebase deploy --only hosting
🔮 Future Roadmap
Predictive AI Dispatch: Integrating Google Vertex AI to analyze historical mission data and predict future crisis hotspots before they occur.

IoT Sensor Integration: Connecting the system to smart water meters and environmental sensors to trigger automated mission deployments.

Fleet Optimization: Implementing Google OR-Tools to manage multi-agent routing for large-scale disaster responses.

Offline-First Resilience: Caching map data locally to allow drivers to navigate without active cellular connections.
