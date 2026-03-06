# Screen Descriptions

## Navigation Flow

```
SplashScreen (1.5s)
    └── HomeScreen
            ├── [New Patient] ──► SymptomsScreen
            │                         └── InvestigationScreen
            │                                  └── ManagementScreen
            │                                           └── ReportScreen
            │                                                    └── HomeScreen
            └── [Chat AI] ──► ChatIntroScreen
                                   └── ChatScreen
```

---

## 1. SplashScreen

**File:** `lib/screens/splash_screen.dart`

**Purpose:** App entry point with animated logo. Auto-navigates to HomeScreen.

**Behavior:**
- Fade + scale animation plays over 1.2s
- After 2.2s total, fades to HomeScreen

**No API calls.**

---

## 2. HomeScreen

**File:** `lib/screens/home_screen.dart`

**Purpose:** Main menu with two navigation options.

**UI Elements:**
- App logo + title header
- "New Patient" card → navigates to SymptomsScreen
- "Chat AI" card → navigates to ChatIntroScreen

**No API calls.**

---

## 3. SymptomsScreen

**File:** `lib/screens/patient/symptoms_screen.dart`

**Purpose:** Collect patient information and symptoms to register a new patient.

**Form Fields:**
| Field | Required | Notes |
|-------|----------|-------|
| Full Name | Yes | |
| Age | Yes | Numeric |
| Sex | Yes | Dropdown: Male / Female |
| Allergies | No | Free text |
| Pre-existing Conditions | No | Free text |
| Symptoms | Yes | Multi-line, describe in detail |

**On Submit:**
1. Validates all required fields
2. Calls `POST /patients` with form data
3. Shows loading state: "AI is analysing patient data..."
4. Backend AI generates investigations + management plan
5. Navigates to InvestigationScreen with `patient_id`

**API Call:** `POST /patients`

---

## 4. InvestigationScreen

**File:** `lib/screens/patient/investigation_screen.dart`

**Purpose:** Display the AI-recommended investigations. Allow doctor to enter results for each.

**UI:**
- Numbered list of investigation items
- Items without results show: "Tap to enter result" + edit icon
- Items with results show the result text + checkmark
- Tapping opens a dialog to enter/edit the result

**On Result Save:**
1. Calls `PUT /investigations/:id` with result text + patient_id
2. Backend AI reconsiders management plan with new data
3. Shows snackbar: "Result saved. Management plan updated by AI."
4. Refreshes the list

**API Calls:**
- `GET /patients/:patient_id/investigations` (on load)
- `PUT /investigations/:investigation_id` (on each result save)

**Navigation:** Next → ManagementScreen | Back → SymptomsScreen

---

## 5. ManagementScreen

**File:** `lib/screens/patient/management_screen.dart`

**Purpose:** Display the AI management plan (ordered high to low priority).

**UI:**
- Numbered list of management items
- Each item shows priority number + text
- Updated automatically when investigation results are added (via InvestigationScreen)

**API Call:** `GET /patients/:patient_id/management` (on load)

**Navigation:** Next → ReportScreen | Back → InvestigationScreen

---

## 6. ReportScreen

**File:** `lib/screens/patient/report_screen.dart`

**Purpose:** Full patient summary — all info, investigations with results, and management plan in one view.

**Sections:**
1. **Patient** — name, age, sex, allergies, pre-existing conditions
2. **Symptoms** — full symptom description
3. **Investigations** — each item + result (if entered)
4. **Management Plan** — prioritized list

**API Calls (parallel):**
- `GET /patients/:patient_id`
- `GET /patients/:patient_id/investigations`
- `GET /patients/:patient_id/management`

**Navigation:** Done → HomeScreen (clears navigation stack)

---

## 7. ChatIntroScreen

**File:** `lib/screens/chat/chat_intro_screen.dart`

**Purpose:** Intro/welcome screen before starting a chat session.

**UI:**
- App icon
- Welcome message
- Three feature highlights (evidence-based, memory, drug info)
- "Start Conversation" button

**No API calls.**

**Navigation:** Start → ChatScreen

---

## 8. ChatScreen

**File:** `lib/screens/chat/chat_screen.dart`

**Purpose:** Full conversational AI chat interface.

**UI:**
- Chat bubbles (user = right/dark blue, AI = left/white)
- AI responses rendered as Markdown (supports bold, lists, etc.)
- Animated typing indicator (three bouncing dots) while waiting
- Input bar with multi-line text field and send button
- Clear chat button in app bar

**Behavior:**
- Loads `user_id` from SharedPreferences (set at login)
- Falls back to `'guest'` if not logged in
- History is stored in MongoDB and automatically sent to the AI on each message

**API Calls:**
- `POST /ai_response` (on each message sent)
- `DELETE /chat/:user_id` (on clear button)
