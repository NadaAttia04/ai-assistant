# API Reference

Base URL: `http://localhost:5000`

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

Register a new doctor account.

**Request**
```json
{
  "name": "Dr. Sarah Ahmed",
  "email": "sarah@hospital.com",
  "password": "secure123"
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
  "name": "Dr. Sarah Ahmed"
}
```

**Response `401`**
```json
{ "error": "Invalid credentials" }
```

---

### GET /users/:user_id

**Response `200`**
```json
{
  "_id": "65aae779c4a0b78b055b96ec",
  "name": "Dr. Sarah Ahmed",
  "email": "sarah@hospital.com"
}
```

---

## Chat

### POST /ai_response

Send a message to the AI. Conversation history is stored per `user_id` in MongoDB and passed automatically to the model.

**Request**
```json
{
  "query": "What is the first-line treatment for type 2 diabetes?",
  "user_id": "65aae779c4a0b78b055b96ec"
}
```

**Response `200`**
```json
{
  "response": "The first-line treatment for type 2 diabetes is metformin..."
}
```

---

### DELETE /chat/:user_id

Clear a user's chat history from the database.

**Response `200`**
```json
{ "message": "Chat history cleared" }
```

---

## Patients

### POST /patients

Register a new patient. Triggers two AI calls:
1. Generates investigation recommendations
2. Generates management plan

Both are stored in MongoDB before responding.

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

> Note: This call may take 5-10 seconds as it makes two AI requests.

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
    { "_id": "...", "name": "John Doe", ... },
    { "_id": "...", "name": "Jane Smith", ... }
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
    {
      "_id": "65ccg901e6c2d90d277e18ge",
      "patient_id": "65bbf890d5b1c89c166d07fd",
      "text": "12-lead ECG",
      "result": null
    },
    {
      "_id": "65ccg902e6c2d90d277e18gf",
      "patient_id": "65bbf890d5b1c89c166d07fd",
      "text": "Troponin I/T levels",
      "result": "Troponin T: 0.8 ng/mL (elevated)"
    }
  ]
}
```

---

### PUT /investigations/:investigation_id

Save the result of an investigation. Triggers AI to reconsider the management plan with the new information.

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
    { "_id": "...", "patient_id": "...", "text": "Urgent cardiology referral" },
    { "_id": "...", "patient_id": "...", "text": "Aspirin 300mg loading dose" }
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
    {
      "_id": "65ddhj012f7d3a01e388f29hg",
      "patient_id": "65bbf890d5b1c89c166d07fd",
      "text": "Urgent cardiology referral for STEMI workup"
    },
    {
      "_id": "65ddhj013f7d3a01e388f29hh",
      "patient_id": "65bbf890d5b1c89c166d07fd",
      "text": "Aspirin 300mg loading dose, then 75mg daily"
    }
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
