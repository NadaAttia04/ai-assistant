# AI Medical Assistant

A cross-platform mobile AI assistant for patients and doctors, built with Flutter (Android + iOS) and a Python Flask backend powered by Google Gemini 2.5 Flash (free).

Based on the Hakeem-AI architecture, simplified to use the Gemini REST API directly — no LangChain, no vector databases, no paid services required.

---

## Features

### Authentication & Roles
- **Login / Register** — email + password with tabbed UI
- **Forgot Password** — email-based reset flow
- **Guest Access** — continue without an account
- **Role Selection** — Patient or Doctor, each with a dedicated home screen

### Patient
- **AI Chat** — conversational medical assistant with per-session history, Markdown rendering, severity badges (mild / moderate / severe), reply-to, and message search
- **Speech-to-Text** — live voice input using device system locale; red hint shows while listening
- **Text-to-Speech** — AI reads responses aloud
- **Book a Doctor** — browse doctors by specialty, view ratings/prices, select available time slots
- **Pharmacy** — browse 20 medicines, add to cart, apply promo codes (HEALTH10 / SAVE20 / WELCOME15), checkout with Cash on Delivery or Credit/Debit Card (with validation)
- **Medication Reminders** — schedule and manage medication alerts
- **Consultations** — real-time Patient↔Doctor direct chat (polled every 5 s)
- **Activity Tracking** — log and view health activities
- **Support** — contact via phone/WhatsApp (`01063334273`)
- **PDF Export** — export any chat session as a PDF report

### Doctor
- **Doctor Dashboard** — stats header + quick actions (New Patient, AI Chat, Appointments, Queue, Activity, Consultations)
- **New Patient Flow** — register a patient, describe symptoms, get AI-generated investigation recommendations and a management plan
- **Investigation Results** — enter lab/test results; AI reconsiders and updates the management plan
- **Appointments** — tabbed view of upcoming and past appointments
- **Patient Queue** — priority-based patient list
- **AI Chat** — professional-tone medical assistant (role-aware system prompt)
- **Consultations** — respond to patient direct messages

### Chat Features
- Drawer side menu: session list, new chat, dark mode toggle, medications, logout, medical disclaimer
- Severity badge on AI messages (mild / moderate / severe) parsed from AI response
- Reply-to, message search, image attachments, PDF export
- Dark mode support
- Offline caching for messages

### Backend
- **Role-aware AI** — patient gets simple language, doctor gets clinical/professional tone
- **Gemini retry + fallback** — `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite`, retries on 429/503
- **Consultation rooms** — persistent Patient↔Doctor message threads
- **Profile management** — update name, phone, age, address, city, governorate
- **Zero-setup database** — local JSON storage by default; swap to MongoDB when ready

### Notifications
- 4 channels: Medication, Appointment, Order, Message
- Sound + vibration on all channels

---

## Architecture

```
┌─────────────────────────────┐        HTTP/JSON        ┌──────────────────────────────┐
│        Flutter App          │ ─────────────────────── │      Python Flask API        │
│     (Android + iOS)         │                         │                              │
│                             │                         │  ┌──────────────────────┐    │
│  SplashScreen               │   POST /auth/login      │  │  Gemini 2.5 Flash    │    │
│  LoginScreen                │   POST /auth/register   │  │  (free REST API)     │    │
│  RoleScreen                 │   PUT  /users/<id>      │  │  retry + fallback    │    │
│                             │                         │  └──────────────────────┘    │
│  PatientHomeScreen          │   POST /patients        │                              │
│  DoctorDashboardScreen      │   GET  /investigations  │  ┌──────────────────────┐    │
│                             │   POST /ai_response     │  │  MongoDB (optional)  │    │
│  ChatScreen                 │   POST /chat            │  │  JSON fallback       │    │
│  ConsultationScreen         │   POST /consultations   │  │  (auto-detected)     │    │
│  PharmacyScreen             │   GET  /doctors         │  └──────────────────────┘    │
│  DoctorBookingSheet         │   GET  /medicines       │                              │
│  ProfileScreen              │                         │                              │
│  ActivityScreen             │                         │                              │
└─────────────────────────────┘                         └──────────────────────────────┘
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

> **Android firewall** (if on Windows host):
> ```
> netsh advfirewall firewall add rule name="Flask 5000" dir=in action=allow protocol=TCP localport=5000
> ```

---

## Project Structure

```
ai-assistant/
├── README.md
├── backend/
│   ├── app.py                        # All Flask routes
│   ├── config.py                     # Env loading
│   ├── requirements.txt
│   ├── .env.example
│   └── modules/
│       ├── ai.py                     # Gemini REST calls, retry + model fallback
│       ├── mongodb.py                # DB layer (MongoDB + JSON fallback)
│       └── services_data.py          # Static doctors/medicines data
└── flutter_app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── theme/app_theme.dart
        │   ├── models/               # message, doctor, medicine, booking, order, chat_session, cart_item
        │   ├── providers/            # State management
        │   └── services/
        │       ├── api_service.dart  # All HTTP calls
        │       ├── stt_service.dart  # Speech-to-Text
        │       ├── tts_service.dart  # Text-to-Speech
        │       ├── notification_service.dart
        │       ├── location_service.dart
        │       ├── activity_service.dart
        │       └── report_service.dart  # PDF generation
        └── screens/
            ├── splash_screen.dart
            ├── role_screen.dart
            ├── auth/
            │   └── login_screen.dart
            ├── patient/
            │   └── patient_home_screen.dart
            ├── doctor/
            │   ├── doctor_dashboard_screen.dart
            │   ├── appointments_screen.dart
            │   └── patient_list_screen.dart
            ├── chat/
            │   ├── chat_intro_screen.dart
            │   ├── chat_screen.dart
            │   ├── chat_history_screen.dart
            │   └── widgets/
            ├── consultation/
            │   └── consultation_screen.dart
            ├── pharmacy/
            ├── medication/
            ├── activity/
            ├── profile/
            │   └── profile_screen.dart
            └── services/
                ├── doctor_booking_sheet.dart
                ├── pharmacy_sheet.dart
                └── support_sheet.dart
```

---

## Tech Stack

| Layer        | Technology                                          |
|--------------|-----------------------------------------------------|
| Mobile       | Flutter 3.x (Dart) — Android + iOS                 |
| Backend      | Python 3.8+, Flask 3.0                             |
| AI           | Google Gemini 2.5 Flash (free REST API)            |
| Database     | MongoDB (optional) with JSON file fallback         |
| STT          | speech_to_text ^7.0.0 (device system locale)       |
| TTS          | flutter_tts ^4.2.0                                 |
| Notifications| flutter_local_notifications ^18.0.1                |
| PDF          | pdf ^3.11.2 + printing ^5.13.1                     |
| State        | provider + shared_preferences                      |

---

## Android Config

- `minSdk=24`, `compileSdk=36`, Kotlin 2.1.0
- Core library desugaring enabled (`isCoreLibraryDesugaringEnabled = true`)
- Permissions: `INTERNET`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`

---

## AI Reliability

The backend uses a **retry + fallback** strategy:
- On 503 / 429 → waits the exact delay Gemini specifies, then retries (up to 3×)
- Falls back through: `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite`
- Severity detection: AI appends `SEVERITY: mild|moderate|severe`, parsed and shown as a badge in chat

---

## Docs

- [API Reference](docs/API.md)
- [Setup Guide](docs/SETUP.md)
- [Screen Descriptions](docs/SCREENS.md)
