# API Reference

Base URL: `http://localhost:5000`
On a physical device, replace with your machine's local IP: `http://192.168.1.x:5000`

All requests and responses use `Content-Type: application/json`.

---

## Health Check

### GET /

```bash
curl http://localhost:5000/
```

**Response**
```json
{ "message": "AI Assistant API", "status": "ok" }
```

---

## Auth

### POST /auth/register

Register a new user account (patient or doctor).

**Request**
```json
{
  "name": "Dr. Sarah Ahmed",
  "email": "sarah@hospital.com",
  "password": "secure123",
  "role": "doctor"
}
```

**Response `201`**
```json
{ "user_id": "65aae779c4a0b78b055b96ec" }
```

**Response `409`** — email already registered
```json
{ "error": "Email already registered" }
```

---

### POST /auth/login

**Request**
```json
{
  "email": "sarah@hospital.com",
  "password": "secure123"
}
```

**Response `200`**
```json
{
  "user_id": "65aae779c4a0b78b055b96ec",
  "name": "Dr. Sarah Ahmed",
  "role": "doctor"
}
```

**Response `401`**
```json
{ "error": "Invalid credentials" }
```

---

### POST /auth/forgot_password

Check email existence and trigger simulated password reset.

**Request**
```json
{ "email": "sarah@hospital.com" }
```

**Response `200`**
```json
{ "message": "Password reset email sent" }
```

---

### POST /auth/change_password

Change password with current password verification.

**Request**
```json
{
  "user_id": "65aae779c4a0b78b055b96ec",
  "current_password": "old123",
  "new_password": "new456"
}
```

**Response `200`**
```json
{ "message": "Password updated successfully" }
```

**Response `401`**
```json
{ "error": "Current password is incorrect" }
```

---

### GET /users/:user_id

**Response `200`**
```json
{
  "_id": "65aae779c4a0b78b055b96ec",
  "name": "Dr. Sarah Ahmed",
  "email": "sarah@hospital.com",
  "role": "doctor",
  "phone": "01012345678",
  "age": "35",
  "address": "123 Main St",
  "city": "Cairo",
  "governorate": "Cairo"
}
```

---

### PUT /users/:user_id

Update user profile fields.

**Request**
```json
{
  "name": "Dr. Sarah Ahmed",
  "phone": "01012345678",
  "age": "35",
  "address": "123 Main St",
  "city": "Cairo",
  "governorate": "Cairo"
}
```

**Response `200`**
```json
{ "message": "Profile updated successfully" }
```

---

## Chat

### POST /ai_response

Send a message to the AI. Conversation history is stored per `user_id` and passed automatically to the model. Role-aware: patient gets simple language, doctor gets clinical tone.

**Request**
```json
{
  "query": "What is the first-line treatment for type 2 diabetes?",
  "user_id": "65aae779c4a0b78b055b96ec",
  "role": "doctor"
}
```

**Response `200`**
```json
{
  "response": "The first-line treatment for type 2 diabetes is metformin...\nSEVERITY: mild"
}
```

> The AI appends `SEVERITY: mild|moderate|severe` — the app parses and strips it for display as a badge.

---

### DELETE /chat/:user_id

Clear a user's chat history.

**Response `200`**
```json
{ "message": "Chat history cleared" }
```

---

## Consultations

### POST /consultations

Create or retrieve a consultation room between a patient and doctor.

**Request**
```json
{
  "patient_id": "65aae779c4a0b78b055b96ec",
  "doctor_id": "65bbf890d5b1c89c166d07fd",
  "patient_name": "John Doe",
  "doctor_name": "Dr. Sarah Ahmed"
}
```

**Response `200`**
```json
{ "room_id": "65ccg901e6c2d90d277e18ge" }
```

---

### GET /consultations/:room_id/messages

Get all messages in a consultation room.

**Response `200`**
```json
{
  "messages": [
    {
      "_id": "...",
      "sender_role": "patient",
      "sender_name": "John Doe",
      "content": "I've been having chest pain",
      "timestamp": "2026-04-03T10:00:00Z"
    }
  ]
}
```

---

### POST /consultations/:room_id/message

Send a message in a consultation room.

**Request**
```json
{
  "sender_role": "doctor",
  "sender_name": "Dr. Sarah Ahmed",
  "content": "Please describe the pain location and intensity."
}
```

**Response `200`**
```json
{ "message": "Message sent" }
```

---

### GET /consultations/patient/:patient_id

List all consultation rooms for a patient.

**Response `200`**
```json
{
  "consultations": [
    {
      "_id": "65ccg901e6c2d90d277e18ge",
      "doctor_name": "Dr. Sarah Ahmed",
      "created_at": "2026-04-03T09:00:00Z"
    }
  ]
}
```

---

### GET /consultations/doctor/:doctor_id

List all consultation rooms for a doctor.

**Response `200`**
```json
{
  "consultations": [
    {
      "_id": "65ccg901e6c2d90d277e18ge",
      "patient_name": "John Doe",
      "created_at": "2026-04-03T09:00:00Z"
    }
  ]
}
```

---

## Doctors

### GET /doctors

Get all available doctors.

**Response `200`**
```json
{
  "doctors": [
    {
      "id": "1",
      "name": "Dr. Sarah Ahmed",
      "specialty": "Cardiology",
      "rating": 4.8,
      "price": 300,
      "experienceYears": 10,
      "hospital": "Cairo Medical Center",
      "availableTimes": ["09:00 AM", "11:00 AM", "02:00 PM"]
    }
  ]
}
```

---

## Medicines

### GET /medicines

Get all available medicines.

**Response `200`**
```json
{
  "medicines": [
    {
      "id": "1",
      "name": "Paracetamol 500mg",
      "category": "Pain Relief",
      "price": 25.0,
      "inStock": true,
      "requiresPrescription": false,
      "quantityAvailable": 100
    }
  ]
}
```

---

## Patients

### POST /patients

Register a new patient. Triggers two AI calls: investigation recommendations + management plan.

**Request**
```json
{
  "doctor_id": "65aae779c4a0b78b055b96ec",
  "name": "John Doe",
  "sex": "Male",
  "age": "45",
  "symptoms": "Chest pain radiating to left arm, shortness of breath, sweating",
  "allergies": "Penicillin",
  "pre_existing_conditions": "Hypertension, type 2 diabetes"
}
```

**Response `201`**
```json
{ "patient_id": "65bbf890d5b1c89c166d07fd" }
```

> This call may take 5–10 seconds as it makes two AI requests.

---

### GET /patients/:patient_id

**Response `200`**
```json
{
  "_id": "65bbf890d5b1c89c166d07fd",
  "doctor_id": "65aae779c4a0b78b055b96ec",
  "name": "John Doe",
  "sex": "Male",
  "age": "45",
  "allergies": "Penicillin",
  "symptoms": "Chest pain radiating to left arm...",
  "pre_existing_conditions": "Hypertension, type 2 diabetes"
}
```

---

### GET /patients/doctor/:doctor_id

Get all patients for a doctor.

**Response `200`**
```json
{
  "patients": [
    { "_id": "...", "name": "John Doe" },
    { "_id": "...", "name": "Jane Smith" }
  ]
}
```

---

## Investigations

### GET /patients/:patient_id/investigations

**Response `200`**
```json
{
  "investigations": [
    { "_id": "...", "patient_id": "...", "text": "12-lead ECG", "result": null },
    { "_id": "...", "patient_id": "...", "text": "Troponin I/T levels", "result": "Troponin T: 0.8 ng/mL (elevated)" }
  ]
}
```

---

### PUT /investigations/:investigation_id

Save result and trigger AI to update the management plan.

**Request**
```json
{
  "result": "Troponin T: 0.8 ng/mL (elevated)",
  "patient_id": "65bbf890d5b1c89c166d07fd"
}
```

**Response `200`**
```json
{
  "message": "Result saved, management updated",
  "management": [
    { "_id": "...", "patient_id": "...", "text": "Urgent cardiology referral" }
  ]
}
```

---

## Management

### GET /patients/:patient_id/management

**Response `200`**
```json
{
  "management": [
    { "_id": "...", "patient_id": "...", "text": "Urgent cardiology referral for STEMI workup" },
    { "_id": "...", "patient_id": "...", "text": "Aspirin 300mg loading dose, then 75mg daily" }
  ]
}
```

---

## Error Format

All errors return a JSON object with an `error` key:

```json
{ "error": "Description of what went wrong" }
```

| Status | Meaning                     |
|--------|-----------------------------|
| 400    | Missing or invalid fields   |
| 401    | Authentication failed       |
| 404    | Resource not found          |
| 409    | Conflict (duplicate email)  |
| 500    | Server or AI error          |
