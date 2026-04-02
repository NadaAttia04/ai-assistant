import base64
import json
import time
import requests
from config import GEMINI_API_KEY

MODELS = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
MAX_HISTORY = 20
MAX_RETRIES = 3


# ── Low-level Gemini call ──────────────────────────────────────────────────────

def _call_model(model, system_prompt, contents, temperature):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": contents,
        "generationConfig": {"temperature": temperature},
    }
    response = requests.post(
        url, params={"key": GEMINI_API_KEY}, json=payload, timeout=60
    )
    response.raise_for_status()
    return response.json()["candidates"][0]["content"]["parts"][0]["text"].strip()


def _call_with_retry(system_prompt, contents, temperature=0.3):
    last_error = None
    for model in MODELS:
        for attempt in range(MAX_RETRIES):
            try:
                result = _call_model(model, system_prompt, contents, temperature)
                if model != MODELS[0]:
                    print(f"[AI] Used fallback model: {model}")
                return result
            except requests.HTTPError as e:
                status = e.response.status_code if e.response else 0
                last_error = e
                if status in (429, 503):
                    wait = _parse_retry_delay(e.response) or (2 ** (attempt + 2))
                    print(f"[AI] {status} on {model}, retrying in {wait:.0f}s...")
                    time.sleep(wait)
                    continue
                else:
                    break
            except Exception as e:
                last_error = e
                break
    raise Exception("The AI service is currently unavailable after multiple retries. Please try again in a few seconds.")


def _parse_retry_delay(response):
    try:
        details = response.json().get("error", {}).get("details", [])
        for d in details:
            delay = d.get("retryDelay", "")
            if delay:
                return float(delay.replace("s", "").strip()) + 1
    except Exception:
        pass
    return None


def _history_to_contents(history):
    contents = []
    for m in history:
        role = "model" if m["role"] == "assistant" else "user"
        contents.append({"role": role, "parts": [{"text": m["content"]}]})
    while contents and contents[0]["role"] != "user":
        contents.pop(0)
    return contents


# ── Chat system prompt ─────────────────────────────────────────────────────────

_PATIENT_INSTRUCTION = (
    "You are speaking with a PATIENT. Use simple, clear, non-technical language. "
    "Avoid medical jargon. Be empathetic and reassuring."
)
_DOCTOR_INSTRUCTION = (
    "You are speaking with a DOCTOR. Use full professional medical terminology. "
    "Include clinical details, differentials, evidence-based guidelines, and drug dosages where relevant."
)

_CHAT_SYSTEM_BASE = """You are a professional medical AI assistant.

STRICT RULES — follow without exception:
1. ONLY answer questions related to medicine, health, symptoms, diagnoses, medications, treatments, anatomy, physiology, nutrition, mental health, or clinical guidelines.
2. If the question is NOT related to health or medicine in any way, respond ONLY with this exact sentence: "I'm a medical assistant and can only help with health-related questions."
3. Respond in the SAME language the user writes in (Arabic, English, French, etc.).
4. {role_instruction}
5. For emergency symptoms (chest pain, difficulty breathing, signs of stroke), always recommend seeking immediate emergency care.
6. Never provide a definitive diagnosis — recommend professional consultation for serious concerns.
7. When analyzing images or files, describe relevant medical findings clearly.
8. If the symptom description is vague, ask 1-2 targeted clarifying questions.
9. For symptom-related questions, append on its own line at the very end: SEVERITY: mild  OR  SEVERITY: moderate  OR  SEVERITY: severe"""


def _build_chat_system(role: str) -> str:
    instruction = _DOCTOR_INSTRUCTION if role == "doctor" else _PATIENT_INSTRUCTION
    return _CHAT_SYSTEM_BASE.format(role_instruction=instruction)


# ── Severity parsing ──────────────────────────────────────────────────────────

def _parse_severity(text: str):
    """Extract and strip the SEVERITY tag. Returns (clean_text, severity_or_None)."""
    import re
    match = re.search(r'\bSEVERITY:\s*(mild|moderate|severe)\b', text, re.IGNORECASE)
    if match:
        severity = match.group(1).lower()
        clean = re.sub(r'\s*\bSEVERITY:\s*(mild|moderate|severe)\b', '', text, flags=re.IGNORECASE).strip()
        return clean, severity
    return text, None


# ── Text chat ──────────────────────────────────────────────────────────────────

def get_chat_response(user_query, history, role="patient"):
    trimmed = list(history[-MAX_HISTORY:])
    trimmed.append({"role": "user", "content": user_query})
    contents = _history_to_contents(trimmed)
    raw = _call_with_retry(_build_chat_system(role), contents)
    text, severity = _parse_severity(raw)
    return text, severity


# ── Attachment chat (image OR file) ───────────────────────────────────────────

def get_chat_response_with_attachment(text, data_bytes, mime_type, history, role="patient"):
    """Handle any binary attachment (image or PDF) alongside optional text."""
    trimmed = list(history[-MAX_HISTORY:])
    contents = _history_to_contents(trimmed)
    parts = []
    if text:
        parts.append({"text": text})
    parts.append({
        "inline_data": {
            "mime_type": mime_type,
            "data": base64.b64encode(data_bytes).decode("utf-8"),
        }
    })
    contents.append({"role": "user", "parts": parts})
    while contents and contents[0]["role"] != "user":
        contents.pop(0)
    raw = _call_with_retry(_build_chat_system(role), contents)
    return _parse_severity(raw)


# Alias kept for backward compat with old /ai_response_multimodal endpoint
def get_chat_response_with_image(text, image_bytes, mime_type, history):
    text, _ = get_chat_response_with_attachment(text, image_bytes, mime_type, history)
    return text


# ── Medical report generation ─────────────────────────────────────────────────

REPORT_SYSTEM = """You are a professional medical documentation assistant.
Generate a structured medical consultation report from the provided conversation.
Format the report in clean markdown with sections:
## Patient Consultation Report
### Summary
### Key Symptoms / Concerns
### AI Assessment
### Recommendations
### Important Disclaimer
Keep it professional and concise."""


def generate_medical_report(messages, role="patient"):
    """Generate a medical report from a list of {role, content} dicts."""
    conversation = "\n".join(
        f"{'Patient' if m['role'] == 'user' else 'AI'}: {m['content']}"
        for m in messages if m.get("content")
    )
    prompt = f"Role context: {role}\n\nConversation:\n{conversation}"
    return _call_with_retry(
        REPORT_SYSTEM,
        [{"role": "user", "parts": [{"text": prompt}]}],
        temperature=0.2,
    )


# ── Investigation recommendations ──────────────────────────────────────────────

INVESTIGATION_SYSTEM = """You are a medical expert. Based on the patient data and symptoms provided,
recommend the most relevant diagnostic investigations.
Return ONLY a valid JSON object in this exact format, nothing else:
{"investigations": ["Investigation 1", "Investigation 2", "Investigation 3"]}
Order from highest to lowest priority. Maximum 5 items."""


def get_investigation_recommendations(patient_data, symptoms):
    prompt = f"Patient: {patient_data}\nSymptoms: {symptoms}"
    raw = _call_with_retry(
        INVESTIGATION_SYSTEM,
        [{"role": "user", "parts": [{"text": prompt}]}],
        temperature=0.1,
    )
    return _parse_list(raw, "investigations")


# ── Management recommendations ─────────────────────────────────────────────────

MANAGEMENT_SYSTEM = """You are a medical expert. Based on the patient data, symptoms, and investigations,
recommend the most relevant management plan.
Return ONLY a valid JSON object in this exact format, nothing else:
{"management": ["Step 1", "Step 2", "Step 3"]}
Order from highest to lowest priority. Maximum 5 items."""


def get_management_recommendations(patient_data, symptoms, investigations):
    prompt = f"Patient: {patient_data}\nSymptoms: {symptoms}\nInvestigations: {investigations}"
    raw = _call_with_retry(
        MANAGEMENT_SYSTEM,
        [{"role": "user", "parts": [{"text": prompt}]}],
        temperature=0.1,
    )
    return _parse_list(raw, "management")


# ── Reconsider management ──────────────────────────────────────────────────────

RECONSIDER_SYSTEM = """You are a medical expert. The patient's investigation results are now available.
Based on the updated results and existing management plan, provide a revised management plan.
Return ONLY a valid JSON object in this exact format, nothing else:
{"management": ["Step 1", "Step 2", "Step 3"]}
Order from highest to lowest priority. Maximum 5 items."""


def reconsider_management(patient_data, investigations_with_results, current_management):
    prompt = (
        f"Patient: {patient_data}\n"
        f"Investigation results: {investigations_with_results}\n"
        f"Current management: {current_management}"
    )
    raw = _call_with_retry(
        RECONSIDER_SYSTEM,
        [{"role": "user", "parts": [{"text": prompt}]}],
        temperature=0.1,
    )
    return _parse_list(raw, "management")


# ── Helpers ────────────────────────────────────────────────────────────────────

def _parse_list(raw, key):
    try:
        cleaned = raw.replace("```json", "").replace("```", "").strip()
        data = json.loads(cleaned)
        return data.get(key, [])
    except Exception as e:
        print(f"[AI] JSON parse error: {e}\nRaw: {raw}")
        return []
