# AI Medical Assistant — Project Plan

## Overview

A cross-platform mobile AI assistant for patients and doctors, built with Flutter (Android + iOS) and a Python Flask backend powered by Google Gemini 2.5 Flash (free REST API).

Based on the Hakeem-AI medical assistant architecture — no LangChain, no vector databases, no paid AI services required.

---

## Tech Stack

| Layer         | Technology                                           |
|---------------|------------------------------------------------------|
| Mobile        | Flutter 3.x (Dart) — Android + iOS                  |
| Backend       | Python 3.8+, Flask 3.0, Flask-CORS                  |
| AI            | Google Gemini 2.5 Flash (direct REST API)            |
| Database      | MongoDB (optional) with local JSON file fallback     |
| STT           | speech_to_text ^7.0.0 (device system locale)         |
| TTS           | flutter_tts ^4.2.0                                   |
| Notifications | flutter_local_notifications ^18.0.1                  |
| PDF           | pdf ^3.11.2 + printing ^5.13.1                       |
| State         | provider + shared_preferences                        |

---

## Project Structure

```
ai-assistant/
├── PROJECT_PLAN.md
├── README.md
├── backend/
│   ├── app.py                        # All Flask routes
│   ├── config.py                     # Env var loading
│   ├── requirements.txt
│   ├── .env.example
│   ├── static/                       # Uploaded avatars/files
│   └── modules/
│       ├── ai.py                     # Gemini REST calls, retry + model fallback
│       ├── mongodb.py                # DB layer (MongoDB + JSON fallback)
│       └── services_data.py          # Static doctors & medicines data
└── flutter_app/
    ├── pubspec.yaml
    ├── assets/                       # App icon, images
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── theme/
        │   │   └── app_theme.dart
        │   ├── models/
        │   │   ├── message.dart
        │   │   ├── chat_session.dart
        │   │   ├── patient.dart
        │   │   ├── investigation.dart
        │   │   ├── management.dart
        │   │   ├── doctor.dart
        │   │   ├── medicine.dart
        │   │   ├── booking.dart
        │   │   ├── cart_item.dart
        │   │   └── order.dart
        │   ├── providers/
        │   │   ├── theme_provider.dart
        │   │   └── cart_provider.dart
        │   └── services/
        │       ├── api_service.dart
        │       ├── stt_service.dart
        │       ├── tts_service.dart
        │       ├── notification_service.dart
        │       ├── location_service.dart
        │       ├── activity_service.dart
        │       └── report_service.dart
        └── screens/
            ├── splash_screen.dart
            ├── home_screen.dart
            ├── role_screen.dart
            ├── auth/
            │   └── login_screen.dart
            ├── patient/
            │   ├── patient_home_screen.dart
            │   ├── symptoms_screen.dart
            │   ├── investigation_screen.dart
            │   ├── management_screen.dart
            │   └── report_screen.dart
            ├── doctor/
            │   ├── doctor_dashboard_screen.dart
            │   ├── appointments_screen.dart
            │   ├── patient_list_screen.dart
            │   └── schedule_screen.dart
            ├── chat/
            │   ├── chat_intro_screen.dart
            │   ├── chat_screen.dart
            │   ├── chat_history_screen.dart
            │   └── widgets/
            │       └── chat_drawer.dart
            ├── consultation/
            │   └── consultation_screen.dart
            ├── pharmacy/
            │   ├── pharmacy_screen.dart
            │   ├── cart_screen.dart
            │   └── checkout_screen.dart
            ├── medication/
            │   └── medication_screen.dart
            ├── activity/
            │   ├── activity_screen.dart
            │   ├── booking_detail_screen.dart
            │   └── order_detail_screen.dart
            ├── profile/
            │   └── profile_screen.dart
            └── services/
                ├── doctor_booking_sheet.dart
                ├── pharmacy_sheet.dart
                └── support_sheet.dart
```

---

## Screens

### Auth & Navigation

| # | Screen         | File                          | Description                                                        |
|---|----------------|-------------------------------|--------------------------------------------------------------------|
| 1 | SplashScreen   | `splash_screen.dart`          | Animated logo; checks `user_id` → redirects to home or login      |
| 2 | LoginScreen    | `auth/login_screen.dart`      | Sign In / Register tabs + Forgot Password + Continue as Guest      |
| 3 | RoleScreen     | `role_screen.dart`            | Patient or Doctor selection → routes to appropriate home screen    |

### Patient Screens

| # | Screen              | File                              | Description                                                              |
|---|---------------------|-----------------------------------|--------------------------------------------------------------------------|
| 4 | PatientHomeScreen   | `patient/patient_home_screen.dart`| Hero Chatbot card + service grid (Book Doctor, Pharmacy, Meds, etc.)     |
| 5 | SymptomsScreen      | `patient/symptoms_screen.dart`    | Patient form → POST /patients → AI generates investigations + plan        |
| 6 | InvestigationScreen | `patient/investigation_screen.dart`| Enter lab results per investigation; AI updates management plan          |
| 7 | ManagementScreen    | `patient/management_screen.dart`  | Prioritized AI management plan                                           |
| 8 | ReportScreen        | `patient/report_screen.dart`      | Full patient summary: demographics, symptoms, investigations, plan        |

### Doctor Screens

| # | Screen                  | File                                  | Description                                              |
|---|-------------------------|---------------------------------------|----------------------------------------------------------|
| 9 | DoctorDashboardScreen   | `doctor/doctor_dashboard_screen.dart` | Stats header + quick actions grid                        |
|10 | AppointmentsScreen      | `doctor/appointments_screen.dart`     | Tabbed: Upcoming / Past appointments                     |
|11 | PatientListScreen       | `doctor/patient_list_screen.dart`     | Priority-sorted patient queue with severity badges       |
|12 | ScheduleScreen          | `doctor/schedule_screen.dart`         | Doctor schedule management                               |

### Chat Screens

| # | Screen             | File                          | Description                                                              |
|---|--------------------|-------------------------------|--------------------------------------------------------------------------|
|13 | ChatIntroScreen    | `chat/chat_intro_screen.dart` | Welcome + feature highlights; Start Conversation button                  |
|14 | ChatScreen         | `chat/chat_screen.dart`       | Full AI chat: bubbles, Markdown, STT, TTS, severity badge, PDF, drawer   |
|15 | ChatHistoryScreen  | `chat/chat_history_screen.dart`| All past chat sessions; tap to resume                                   |

### Consultation Screens

| # | Screen               | File                                    | Description                                        |
|---|----------------------|-----------------------------------------|----------------------------------------------------|
|16 | ConsultationScreen   | `consultation/consultation_screen.dart` | Patient↔Doctor direct chat, polled every 5 s       |

### Pharmacy Screens

| # | Screen          | File                           | Description                                             |
|---|-----------------|--------------------------------|---------------------------------------------------------|
|17 | PharmacyScreen  | `pharmacy/pharmacy_screen.dart`| Browse 20 medicines; add to cart; promo codes            |
|18 | CartScreen      | `pharmacy/cart_screen.dart`    | Cart review + delivery fee + promo code application      |
|19 | CheckoutScreen  | `pharmacy/checkout_screen.dart`| COD or Credit/Debit Card checkout with validation        |

### Other Screens

| # | Screen              | File                                     | Description                                    |
|---|---------------------|------------------------------------------|------------------------------------------------|
|20 | MedicationScreen    | `medication/medication_screen.dart`      | Schedule + manage medication reminders          |
|21 | ActivityScreen      | `activity/activity_screen.dart`          | Log and view health activities                 |
|22 | BookingDetailScreen | `activity/booking_detail_screen.dart`    | View appointment booking details               |
|23 | OrderDetailScreen   | `activity/order_detail_screen.dart`      | View pharmacy order details                    |
|24 | ProfileScreen       | `profile/profile_screen.dart`            | Edit profile, change password, logout          |

### Service Sheets (Bottom Sheets)

| # | Screen              | File                                     | Description                                    |
|---|---------------------|------------------------------------------|------------------------------------------------|
|25 | DoctorBookingSheet  | `services/doctor_booking_sheet.dart`     | Browse doctors, view info, book a slot         |
|26 | PharmacySheet       | `services/pharmacy_sheet.dart`           | Quick pharmacy entry point                     |
|27 | SupportSheet        | `services/support_sheet.dart`            | Contact via phone/WhatsApp: 01063334273        |

### Navigation Flow

```
SplashScreen
    └── checks user_id
            ├── [logged in] → user_role → PatientHomeScreen | DoctorDashboardScreen
            └── [not logged in] → LoginScreen
                                      ├── [patient] → RoleScreen → PatientHomeScreen
                                      ├── [doctor]  → RoleScreen → DoctorDashboardScreen
                                      └── [guest]   → PatientHomeScreen

PatientHomeScreen
    ├── AI Chat ──────────► ChatIntroScreen → ChatScreen ↔ ChatHistoryScreen
    ├── Book a Doctor ────► DoctorBookingSheet
    ├── Pharmacy ─────────► PharmacyScreen → CartScreen → CheckoutScreen
    ├── Medication ───────► MedicationScreen
    ├── Consultations ────► ConsultationScreen
    ├── Activity ─────────► ActivityScreen → BookingDetailScreen | OrderDetailScreen
    ├── Support ──────────► SupportSheet
    └── Profile ──────────► ProfileScreen

DoctorDashboardScreen
    ├── New Patient ──────► SymptomsScreen → InvestigationScreen → ManagementScreen → ReportScreen
    ├── AI Chat ──────────► ChatIntroScreen → ChatScreen
    ├── Appointments ─────► AppointmentsScreen
    ├── Patient Queue ────► PatientListScreen
    ├── Activity ─────────► ActivityScreen
    ├── Consultations ────► ConsultationScreen
    └── Profile ──────────► ProfileScreen
```

---

## Backend API Endpoints

### Auth & Users

| Method | Endpoint                    | Description                                      |
|--------|-----------------------------|--------------------------------------------------|
| POST   | `/auth/register`            | Register new user (name, email, password, role)  |
| POST   | `/auth/login`               | Login (email, password) → user_id + role         |
| POST   | `/auth/forgot_password`     | Check email, simulate reset                      |
| POST   | `/auth/change_password`     | Change password with current password verify     |
| GET    | `/users/<user_id>`          | Get user profile                                 |
| PUT    | `/users/<user_id>`          | Update name, phone, age, address, city, gov.     |
| POST   | `/users/<user_id>/avatar`   | Upload profile avatar                            |
| GET    | `/avatars/<filename>`       | Serve avatar image                               |

### Chat

| Method | Endpoint                        | Description                                        |
|--------|---------------------------------|----------------------------------------------------|
| POST   | `/ai_response`                  | Send message to AI (role-aware, with history)      |
| POST   | `/ai_response_multimodal`       | Send message + image to AI                         |
| POST   | `/chat`                         | Send message in a named chat session               |
| DELETE | `/chat/<user_id>`               | Clear all chat history for user                    |
| POST   | `/chats/<user_id>/new`          | Create a new named chat session                    |
| GET    | `/chats/<user_id>`              | List all chat sessions for user                    |
| GET    | `/chats/session/<chat_id>`      | Get all messages in a session                      |
| DELETE | `/chats/session/<chat_id>`      | Delete a chat session                              |

### Media

| Method | Endpoint           | Description                     |
|--------|--------------------|---------------------------------|
| POST   | `/analyze_image`   | Analyze an image with Gemini AI |
| POST   | `/upload_file`     | Upload a file                   |
| POST   | `/generate_report` | Generate a PDF report           |

### Consultations

| Method | Endpoint                                | Description                              |
|--------|-----------------------------------------|------------------------------------------|
| POST   | `/consultations`                        | Create/get consultation room             |
| GET    | `/consultations/<room_id>/messages`     | Get all messages in room                 |
| POST   | `/consultations/<room_id>/message`      | Send a message in room                   |
| GET    | `/consultations/patient/<patient_id>`   | List patient's consultation rooms        |
| GET    | `/consultations/doctor/<doctor_id>`     | List doctor's consultation rooms         |

### Services Data

| Method | Endpoint         | Description                    |
|--------|------------------|--------------------------------|
| GET    | `/doctors`       | List all doctors               |
| GET    | `/medicines`     | List all medicines (20 items)  |
| GET    | `/appointments`  | Get appointments               |
| GET    | `/pending_patients` | Get pending patient queue   |

### Patients & Clinical Flow

| Method | Endpoint                                    | Description                                              |
|--------|---------------------------------------------|----------------------------------------------------------|
| POST   | `/patients`                                 | Register patient + AI generates investigations + plan    |
| GET    | `/patients/<patient_id>`                    | Get patient data                                         |
| GET    | `/patients/doctor/<doctor_id>`              | Get all patients for a doctor                            |
| GET    | `/patients/<patient_id>/investigations`     | Get AI-recommended investigations                        |
| PUT    | `/investigations/<investigation_id>`        | Save result → AI reconsiders management plan             |
| GET    | `/patients/<patient_id>/management`         | Get AI management plan                                   |

---

## AI Layer

### Gemini Integration

- **Direct REST API** — no LangChain or SDK
- **Models (fallback order):** `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite`
- **Retry strategy:** On 429/503, waits exact delay Gemini specifies, retries up to 3×, then falls back to next model
- **Role-aware system prompt:** `_build_chat_system(role)` — patient = simple language, doctor = clinical/professional
- **Severity detection:** AI appends `SEVERITY: mild|moderate|severe`; parsed by `_parse_severity()` and shown as badge in chat
- **Multimodal:** Image + text input supported via `/ai_response_multimodal`

---

## Flutter Dependencies

```yaml
dependencies:
  http: ^1.2.0
  provider: ^6.1.0
  shared_preferences: ^2.2.0
  flutter_markdown: ^0.7.3
  google_fonts: ^6.2.1
  image_picker: ^1.1.2
  speech_to_text: ^7.0.0
  flutter_tts: ^4.2.0
  file_picker: ^8.0.0
  pdf: ^3.11.2
  printing: ^5.13.1
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
  path_provider: ^2.1.4
  url_launcher: ^6.3.0
  geolocator: ^13.0.1
  intl: ^0.20.1
  uuid: ^4.5.1
```

---

## Android Config

| Setting | Value |
|---------|-------|
| `minSdk` | 24 |
| `compileSdk` | 36 |
| Kotlin | 2.1.0 |
| Core desugaring | enabled |

**Permissions:** `INTERNET`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`

---

## Environment Variables

```env
# Backend (.env)
GEMINI_API_KEY=AIza...
MONGODB_URI=mongodb://localhost:27017/   # optional
FLASK_ENV=development
PORT=5000
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Flutter over SwiftUI | Single codebase for Android + iOS |
| Gemini REST over LangChain/OpenAI | Free tier, no third-party SDK dependency |
| Provider over Bloc/Riverpod | Simpler state for this app's complexity |
| MongoDB + JSON fallback | Zero-setup for dev; production-ready with MongoDB |
| Role-aware AI prompts | Patient needs plain language; doctor needs clinical tone |
| Device system locale for STT | Avoids forcing a language; works with user's phone language |

---

## Implementation Status

### Completed

- [x] Flask backend with 30+ endpoints
- [x] Gemini AI integration with retry + model fallback
- [x] Role-aware system prompts (patient / doctor)
- [x] Auth: register, login, forgot password, change password, guest access
- [x] User profiles with avatar upload
- [x] Multi-session chat with history per user
- [x] Multimodal chat (image + text)
- [x] Chat severity badges (mild / moderate / severe)
- [x] PDF export for chat sessions
- [x] Offline message caching
- [x] Doctor new patient flow (symptoms → investigations → management → report)
- [x] Consultation rooms (Patient↔Doctor real-time chat, 5 s polling)
- [x] Doctor dashboard with stats + quick actions
- [x] Appointments screen (tabbed: upcoming / past)
- [x] Patient priority queue
- [x] Pharmacy with 20 medicines, cart, promo codes, COD + card checkout
- [x] Medication reminders with local notifications
- [x] Activity tracking
- [x] Doctor booking
- [x] Profile screen (edit all fields, change password, logout)
- [x] STT voice input (device locale, live transcript)
- [x] TTS text-to-speech for AI responses
- [x] Dark mode (theme provider + drawer toggle)
- [x] Android config (minSdk 24, permissions, desugaring)
- [x] App icon (all resolutions, Android + iOS)
