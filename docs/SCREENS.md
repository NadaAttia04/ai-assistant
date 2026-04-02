# Screen Descriptions

## Navigation Flow

```
SplashScreen
    └── checks user_id (SharedPreferences)
            ├── [logged in] → checks user_role → PatientHomeScreen | DoctorDashboardScreen
            └── [not logged in] → LoginScreen
                                      ├── [patient] → RoleScreen → PatientHomeScreen
                                      ├── [doctor]  → RoleScreen → DoctorDashboardScreen
                                      └── [guest]   → PatientHomeScreen

PatientHomeScreen
    ├── AI Chat ──────────────────────────► ChatIntroScreen → ChatScreen
    ├── Book a Doctor ────────────────────► DoctorBookingSheet
    ├── Pharmacy ─────────────────────────► PharmacyScreen → CartScreen → CheckoutScreen
    ├── Medication Reminders ─────────────► MedicationScreen
    ├── Consultations ────────────────────► ConsultationListScreen → ConsultationScreen
    ├── Activity Tracking ────────────────► ActivityScreen
    ├── Support ──────────────────────────► SupportSheet
    └── Profile (drawer) ─────────────────► ProfileScreen

DoctorDashboardScreen
    ├── New Patient ──────────────────────► SymptomsScreen → InvestigationScreen → ManagementScreen → ReportScreen
    ├── AI Chat ──────────────────────────► ChatIntroScreen → ChatScreen
    ├── Appointments ─────────────────────► AppointmentsScreen
    ├── Patient Queue ────────────────────► PatientListScreen
    ├── Activity ─────────────────────────► ActivityScreen
    ├── Consultations ────────────────────► ConsultationListScreen → ConsultationScreen
    └── Profile (drawer) ─────────────────► ProfileScreen
```

---

## Auth Screens

### SplashScreen
**File:** `lib/screens/splash_screen.dart`

Animated logo entry point. Checks `user_id` in SharedPreferences — if logged in, redirects directly to the appropriate home screen based on `user_role`. Otherwise navigates to LoginScreen.

---

### LoginScreen
**File:** `lib/screens/auth/login_screen.dart`

Tabbed UI with **Sign In** and **Register** tabs.

- **Sign In** — email + password → `POST /auth/login`
- **Register** — name, email, password, role (Patient/Doctor) → `POST /auth/register`
- **Forgot Password?** — email field → `POST /auth/forgot_password`
- **Continue as Guest** — skips auth, proceeds as patient with `user_id = "guest"`

On success, saves `user_id`, `user_name`, and `user_role` to SharedPreferences.

---

### RoleScreen
**File:** `lib/screens/role_screen.dart`

Shown after first login if role needs confirmation. Two cards: Patient and Doctor. Saves selected role and navigates to the appropriate home screen.

---

## Patient Screens

### PatientHomeScreen
**File:** `lib/screens/patient/patient_home_screen.dart`

Service hub for patients. Hero Chatbot card at top + 6-item service grid:

| Card | Navigates To |
|------|-------------|
| Book a Doctor | DoctorBookingSheet |
| Pharmacy | PharmacyScreen |
| Medication Reminders | MedicationScreen |
| Support | SupportSheet |
| Activity | ActivityScreen |
| Consultations | ConsultationListScreen |

---

## Doctor Screens

### DoctorDashboardScreen
**File:** `lib/screens/doctor/doctor_dashboard_screen.dart`

Stats header (patients today, appointments, consultations) + quick action grid.

**API Calls:** Stats loaded from backend on mount.

---

### AppointmentsScreen
**File:** `lib/screens/doctor/appointments_screen.dart`

Tabbed view: **Upcoming** and **Past** appointments. Each appointment shows patient name, time, and status.

---

### PatientListScreen
**File:** `lib/screens/doctor/patient_list_screen.dart`

Priority-sorted patient queue. Each row shows patient name, severity badge, and time registered.

---

## New Patient Flow (Doctor)

### SymptomsScreen
**File:** `lib/screens/patient/symptoms_screen.dart`

Form to register a new patient: name, age, sex, allergies, pre-existing conditions, symptoms.

**On Submit:** `POST /patients` → navigates to InvestigationScreen with `patient_id`.

---

### InvestigationScreen
**File:** `lib/screens/patient/investigation_screen.dart`

Numbered list of AI-recommended investigations. Tap any item to enter the lab/test result via a dialog. On save, AI reconsiders the management plan.

**API Calls:**
- `GET /patients/:patient_id/investigations` (load)
- `PUT /investigations/:investigation_id` (save result)

---

### ManagementScreen
**File:** `lib/screens/patient/management_screen.dart`

Prioritized AI management plan. Updates automatically when investigation results are added.

**API Call:** `GET /patients/:patient_id/management`

---

### ReportScreen
**File:** `lib/screens/patient/report_screen.dart`

Full patient summary: demographics, symptoms, investigations + results, management plan.

**API Calls (parallel):**
- `GET /patients/:patient_id`
- `GET /patients/:patient_id/investigations`
- `GET /patients/:patient_id/management`

---

## Chat Screens

### ChatIntroScreen
**File:** `lib/screens/chat/chat_intro_screen.dart`

Welcome screen with feature highlights before starting a session. "Start Conversation" navigates to ChatScreen.

---

### ChatScreen
**File:** `lib/screens/chat/chat_screen.dart`

Full conversational AI chat interface.

**Features:**
- Chat bubbles: user (right/dark blue), AI (left/white)
- Markdown rendering in AI responses
- **Severity badge** on AI messages (mild / moderate / severe)
- **Reply-to** — swipe or long-press a message to reply in context
- **Image attachments** — attach from gallery or camera
- **Speech-to-Text** — tap mic, speak; live transcript appears in input field
- **Text-to-Speech** — AI reads responses aloud
- **Message search** — search bar filters messages in the session
- **PDF export** — export full chat as a PDF report
- **Offline caching** — messages cached locally when offline
- Animated typing indicator while waiting for AI

**Drawer (☰):**
- Session list + new chat
- Dark mode toggle
- Medications shortcut
- New Patient shortcut (doctor only)
- Logout
- Medical disclaimer

**API Calls:**
- `POST /ai_response` (each message)
- `DELETE /chat/:user_id` (clear history)

---

### ChatHistoryScreen
**File:** `lib/screens/chat/chat_history_screen.dart`

List of all past chat sessions. Tap to resume any session.

---

## Consultation Screens

### ConsultationListScreen
**File:** `lib/screens/consultation/consultation_screen.dart`

Lists all consultation rooms for the current user (patient or doctor). Shows the other party's name and last message preview.

**API Calls:**
- `GET /consultations/patient/:patient_id` (patient)
- `GET /consultations/doctor/:doctor_id` (doctor)

---

### ConsultationScreen
**File:** `lib/screens/consultation/consultation_screen.dart`

Real-time Patient↔Doctor direct messaging. Messages polled every 5 seconds.

**API Calls:**
- `GET /consultations/:room_id/messages` (polled every 5 s)
- `POST /consultations/:room_id/message` (send)

---

## Pharmacy Screens

### PharmacyScreen
**File:** `lib/screens/pharmacy/`

Browse 20 medicines by category. Add to cart, view details, prescription indicator.

**Promo codes:** `HEALTH10` (10%), `SAVE20` (20%), `WELCOME15` (15%)

**Delivery:** EGP 15 flat, free over EGP 200

**Checkout options:**
- Cash on Delivery
- Credit/Debit Card — full form with validation (16-digit number, MM/YY expiry, CVV, cardholder name)

---

## Profile Screen

### ProfileScreen
**File:** `lib/screens/profile/profile_screen.dart`

Edit user profile: name, phone, age, address, city, governorate. Change password (requires current password). Logout.

**API Calls:**
- `PUT /users/:user_id` (save profile)
- `POST /auth/change_password` (change password)

---

## Other Screens

### ActivityScreen
**File:** `lib/screens/activity/`

Log and view health activities (steps, exercise, sleep, etc.).

---

### MedicationScreen
**File:** `lib/screens/medication/`

Schedule medication reminders with time, dosage, and recurrence. Notifications fire via `flutter_local_notifications`.

---

### SupportSheet
**File:** `lib/screens/services/support_sheet.dart`

Contact support via phone call or WhatsApp: `01063334273`.
