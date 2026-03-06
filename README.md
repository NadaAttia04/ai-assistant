# AI Assistant

A cross-platform mobile AI assistant for doctors, built with Flutter (Android + iOS) and a Python Flask backend powered by Google Gemini 2.5 Flash (free).

Based on the Hakeem-AI architecture, simplified to use the Gemini REST API directly — no LangChain, no vector databases, no paid services required.

---

## Features

- **New Patient Flow** — register a patient, describe symptoms, and instantly receive AI-generated investigation recommendations and a management plan
- **Investigation Results** — enter lab/test results per investigation; AI automatically reconsiders and updates the management plan
- **Chat AI** — conversational medical assistant with persistent per-user history and Markdown rendering
- **Cross-platform** — single Flutter codebase runs on Android and iOS
- **Zero-setup database** — works out of the box with local JSON storage; swap to MongoDB when ready

---

## Architecture

```
┌─────────────────────────┐        HTTP/JSON        ┌──────────────────────────┐
│      Flutter App        │ ─────────────────────── │     Python Flask API     │
│  (Android + iOS)        │                         │                          │
│                         │   POST /patients        │  ┌────────────────────┐  │
│  SplashScreen           │ ──────────────────────► │  │ Gemini 2.5 Flash   │  │
│  HomeScreen             │                         │  │ (free REST API)    │  │
│  SymptomsScreen         │   GET  /investigations  │  └────────────────────┘  │
│  InvestigationScreen    │ ◄────────────────────── │                          │
│  ManagementScreen       │                         │  ┌────────────────────┐  │
│  ReportScreen           │   POST /ai_response     │  │ MongoDB (optional) │  │
│  ChatIntroScreen        │ ──────────────────────► │  │ JSON fallback      │  │
│  ChatScreen             │                         │  │ (auto-detected)    │  │
└─────────────────────────┘                         │  └────────────────────┘  │
                                                    └──────────────────────────┘
```

---

## Quick Start

### Backend

```bash
cd backend
cp .env.example .env
# Add your free Gemini API key → https://aistudio.google.com/app/apikey

pip install -r requirements.txt
python app.py
# API running at http://localhost:5000
# Uses local JSON storage automatically if MongoDB is not running
```

### Flutter App

```bash
cd flutter_app
flutter pub get

# Android emulator
flutter run

# Physical device — update _base in lib/core/services/api_service.dart
# to your machine's local IP (run ipconfig to find it)
# static const _base = 'http://192.168.1.x:5000';
```

---

## Project Structure

```
ai-assistant/
├── .gitignore
├── PROJECT_PLAN.md
├── README.md
├── backend/
│   ├── app.py                  # All Flask routes (10 endpoints)
│   ├── config.py               # Env loading
│   ├── requirements.txt        # flask, flask-cors, requests, pymongo, python-dotenv
│   ├── .env.example
│   └── modules/
│       ├── ai.py               # Gemini REST calls, retry + model fallback
│       └── mongodb.py          # DB layer (MongoDB + JSON file fallback)
├── flutter_app/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── theme/app_theme.dart       # Colors, typography, button styles
│       │   ├── services/api_service.dart  # All HTTP calls
│       │   └── models/                    # patient, investigation, management, message
│       └── screens/
│           ├── splash_screen.dart
│           ├── home_screen.dart
│           ├── patient/
│           │   ├── symptoms_screen.dart
│           │   ├── investigation_screen.dart
│           │   ├── management_screen.dart
│           │   └── report_screen.dart
│           └── chat/
│               ├── chat_intro_screen.dart
│               └── chat_screen.dart
└── docs/
    ├── API.md       # All endpoints with curl examples
    ├── SETUP.md     # Full setup guide including Android physical device
    └── SCREENS.md   # Screen descriptions and navigation flow
```

---

## Tech Stack

| Layer    | Technology                                  |
|----------|---------------------------------------------|
| Mobile   | Flutter 3.x (Dart) — Android + iOS          |
| Backend  | Python 3.8+, Flask 3.0                      |
| AI       | Google Gemini 2.5 Flash (free REST API)     |
| Database | MongoDB (optional) with JSON file fallback  |

---

## AI Reliability

The backend uses a **retry + fallback** strategy:
- On 503 / 429 → waits the exact delay Gemini specifies, then retries (up to 3×)
- Falls back through: `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite`

---

## Docs

- [API Reference](docs/API.md)
- [Setup Guide](docs/SETUP.md)
- [Screen Descriptions](docs/SCREENS.md)
