# AI Assistant — Project Plan

## Overview

A cross-platform mobile AI assistant app built with Flutter (Android + iOS), powered by a Python Flask backend and LangChain AI agents. Based on the Hakeem-AI medical assistant architecture, adapted into a full-featured Flutter app with Figma designs and complete documentation.

---

## Tech Stack

| Layer       | Technology                                      |
|-------------|------------------------------------------------|
| Mobile      | Flutter (Dart) — Android + iOS                 |
| Backend     | Python 3.11, Flask, Flask-CORS                 |
| AI          | LangChain, OpenAI GPT-4o, Pinecone (RAG)       |
| Database    | MongoDB (Atlas or local)                       |
| Design      | Figma (MCP-generated)                          |
| Docs        | Markdown (README, API, SETUP, SCREENS)         |

---

## Project Structure

```
ai-assistant/
├── PROJECT_PLAN.md
├── README.md
│
├── backend/                          # Python Flask API
│   ├── app.py                        # All Flask routes
│   ├── config.py                     # Env var loading
│   ├── requirements.txt
│   ├── .env.example
│   └── modules/
│       ├── chatbot.py                # LangChain agents (chat + recommendations)
│       ├── mongodb.py                # All DB operations
│       └── agent_tools.py            # RAG tools (clinical + drug summaries)
│
├── flutter_app/                      # Flutter mobile app
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── theme/
│       │   │   └── app_theme.dart    # Colors, text styles, button styles
│       │   ├── services/
│       │   │   └── api_service.dart  # All HTTP calls to backend
│       │   └── models/
│       │       ├── patient.dart
│       │       ├── message.dart
│       │       ├── investigation.dart
│       │       └── management.dart
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
│
└── docs/
    ├── API.md                        # All endpoints with request/response examples
    ├── SETUP.md                      # Installation and env setup
    └── SCREENS.md                    # Screen descriptions and navigation flow
```

---

## Screens

| # | Screen               | Route             | Source (Hakeem-AI)   | Description                                                      |
|---|----------------------|-------------------|----------------------|------------------------------------------------------------------|
| 1 | SplashScreen         | `/`               | ContentView.swift    | Animated logo + app name, auto-navigates to Home after 1.5s     |
| 2 | HomeScreen           | `/home`           | MainView.swift       | Two buttons: "New Patient" and "Chat AI"                         |
| 3 | SymptomsScreen       | `/symptoms`       | SymptomsView.swift   | Patient form (name, age, sex, allergies, symptoms, conditions) → calls POST /patients |
| 4 | InvestigationScreen  | `/investigations` | InvestigationView    | AI-generated test list; tap each to enter result → reconsiders management |
| 5 | ManagementScreen     | `/management`     | ManagementView       | AI management plan list with edit per item                       |
| 6 | ReportScreen         | `/report`         | ReportView.swift     | Full patient summary; Done returns to Home                       |
| 7 | ChatIntroScreen      | `/chat`           | ChatView.swift       | Welcome message, AI description, Start button                    |
| 8 | ChatScreen           | `/chat/session`   | ChatView2.swift      | Bubble chat UI, message input + Send → calls POST /ai_response  |

### Navigation Flow

```
SplashScreen
    └── HomeScreen
            ├── SymptomsScreen
            │       └── InvestigationScreen
            │               └── ManagementScreen
            │                       └── ReportScreen
            │                               └── HomeScreen
            └── ChatIntroScreen
                    └── ChatScreen
```

---

## Backend API Endpoints

| Method | Endpoint                                    | Description                                              |
|--------|---------------------------------------------|----------------------------------------------------------|
| GET    | `/`                                         | Health check                                             |
| POST   | `/ai_response`                              | Chat: `{query, user_id}` → AI response string            |
| POST   | `/patients`                                 | Register patient + auto-generate investigations + mgmt   |
| GET    | `/patients/<patient_id>`                    | Get full patient data                                    |
| GET    | `/patients/all/<user_id>`                   | Get all patients for a doctor                            |
| POST   | `/patients/<patient_id>/symptoms`           | Update patient symptoms                                  |
| GET    | `/patients/<patient_id>/symptoms`           | Get patient symptoms                                     |
| GET    | `/patients/<patient_id>/investigations`     | Get AI-recommended investigations                        |
| GET    | `/patients/<patient_id>/management`         | Get AI management plan                                   |
| PUT    | `/investigations/<investigation_id>/update_results` | Add test result → triggers AI management reconsideration |

---

## AI Layer

### Agents

| Agent                         | Purpose                                                    | Output Format           |
|-------------------------------|------------------------------------------------------------|-------------------------|
| `get_chatbot_response_agent`  | General medical Q&A chat with history                      | Plain text              |
| `get_investigation_recommendations` | Suggest investigations based on patient data + symptoms | JSON `{investigations: [...]}` |
| `get_management_recommendations`    | Suggest management plan                            | JSON `{management: [...]}`     |
| `reconsider`                  | Re-evaluate management after investigation results updated | JSON `{management: [...]}`     |

### RAG Tools (Pinecone)

| Tool                   | Pinecone Index                   | Purpose                          |
|------------------------|----------------------------------|----------------------------------|
| `get_clinical_summaries` | `clinical-knowledge-summaries` | Clinical guideline lookups       |
| `get_drug_summaries`     | `nice-drugs`                   | Drug/medicine information lookup |

### LLM

- Model: `gpt-4o` (upgraded from `gpt-4-1106-preview`)
- Framework: LangChain `>=0.1.0` (upgraded from `0.0.334`)
- Memory: Per-user chat history stored in MongoDB

---

## Flutter Dependencies

```yaml
dependencies:
  http: ^1.2.0               # API calls
  provider: ^6.1.0           # State management
  shared_preferences: ^2.2.0 # Persist user_id locally
  flutter_markdown: ^0.6.18  # Render AI markdown responses in chat
  loading_animation_widget: ^1.2.0  # Loading states
  google_fonts: ^6.1.0       # Typography
```

---

## Figma Design Plan

### Pages
1. **Cover** — Project title, version, date
2. **Design System** — Color palette, typography, component library
3. **Screens** — All 8 screens as separate frames
4. **Flow** — Connected prototype showing navigation

### Color Palette (from Hakeem-AI)
| Token         | Hex       | Usage                        |
|---------------|-----------|------------------------------|
| `primary`     | `#1A3A6B` | Dark blue — backgrounds, buttons |
| `secondary`   | `#2D6BE4` | Blue — accent buttons        |
| `surface`     | `#FFFFFF` | Card backgrounds             |
| `background`  | `#F5F7FA` | Screen backgrounds           |
| `text-primary`| `#1A1A2E` | Body text                    |
| `text-muted`  | `#6B7280` | Subtitles, hints             |

### Components
- AppButton (primary / secondary variant)
- PatientFormField
- InvestigationListItem (with result input)
- ManagementListItem (with edit icon)
- ChatBubble (user / AI variant)
- LoadingOverlay

---

## Documentation Plan

| File               | Contents                                                             |
|--------------------|----------------------------------------------------------------------|
| `README.md`        | Project overview, quick start, architecture diagram, screenshots     |
| `docs/API.md`      | All endpoints with curl examples, request/response JSON schemas      |
| `docs/SETUP.md`    | Prerequisites, env variables, MongoDB setup, Pinecone setup, running locally |
| `docs/SCREENS.md`  | Each screen: purpose, inputs, outputs, API calls, navigation         |

---

## Implementation Phases

### Phase 1 — Foundation (Current)
- [x] Project plan (this document)
- [ ] Backend: Flask app + MongoDB + routes
- [ ] Backend: LangChain AI agents
- [ ] Flutter: Project setup + theme + models + ApiService

### Phase 2 — Core Screens
- [ ] SplashScreen + HomeScreen
- [ ] ChatIntroScreen + ChatScreen (standalone, no patient context)
- [ ] SymptomsScreen (patient form → POST /patients)

### Phase 3 — Patient Flow Screens
- [ ] InvestigationScreen (GET investigations + PUT results)
- [ ] ManagementScreen (GET management + edit)
- [ ] ReportScreen (GET patient data)

### Phase 4 — Design + Docs
- [ ] Figma project (all 8 screens + design system)
- [ ] README.md
- [ ] docs/API.md
- [ ] docs/SETUP.md
- [ ] docs/SCREENS.md

---

## Environment Variables

```env
# Backend (.env)
OPENAI_API_KEY=sk-...
MONGODB_URI=mongodb+srv://...
PINECONE_API_KEY=...
PINECONE_ENVIRONMENT=...
FLASK_ENV=development
PORT=5000

# Flutter (lib/core/config.dart)
BASE_URL=http://localhost:5000
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Flutter over SwiftUI | Single codebase for Android + iOS |
| Provider over Bloc/Riverpod | Simpler state for this app's complexity level |
| LangChain agents over raw OpenAI | Tool calling (RAG) + memory management built-in |
| MongoDB over SQL | Flexible schema for patient data + chat history |
| GPT-4o over GPT-4-1106-preview | More capable, same cost, supported in current API |
| Modern LangChain (>=0.1.0) | Original 0.0.334 is deprecated and broken |
