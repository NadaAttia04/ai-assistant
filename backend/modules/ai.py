import json
import time
import requests
from config import GEMINI_API_KEY

# Try models in order — first available wins
MODELS = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
MAX_HISTORY = 20
MAX_RETRIES = 3


def _call_model(model, system_prompt, contents, temperature):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": contents,
        "generationConfig": {"temperature": temperature},
    }
    response = requests.post(
        url,
        params={"key": GEMINI_API_KEY},
        json=payload,
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()
    return data["candidates"][0]["content"]["parts"][0]["text"].strip()


def _chat(system_prompt, messages, temperature=0.3):
    """
    Call Gemini REST API with automatic retry and model fallback.
    messages: list of {"role": "user"/"assistant", "content": "..."}
    Returns the reply string.
    """
    # Build Gemini contents array (roles: "user" / "model")
    contents = []
    for m in messages:
        role = "model" if m["role"] == "assistant" else "user"
        contents.append({"role": role, "parts": [{"text": m["content"]}]})

    # Gemini requires first message to be from user
    while contents and contents[0]["role"] != "user":
        contents.pop(0)

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
                    break  # non-retryable, try next model
            except Exception as e:
                last_error = e
                break

    raise Exception(f"AI service busy. Please try again in a moment.")


def _parse_retry_delay(response):
    """Extract retryDelay seconds from Gemini 429 response body."""
    try:
        details = response.json().get("error", {}).get("details", [])
        for d in details:
            delay = d.get("retryDelay", "")
            if delay:
                return float(delay.replace("s", "").strip()) + 1
    except Exception:
        pass
    return None


# ── Chat ───────────────────────────────────────────────────────────────────────

CHAT_SYSTEM = """You are a knowledgeable medical AI assistant helping a doctor.
Guide the doctor on investigation, diagnosis, and management based on patient symptoms.
You can also answer general medical questions and give prescription advice.
Pay close attention to patient age, sex, allergies, and any pre-existing conditions.
Ask clarifying questions when needed. Be concise and evidence-based."""


def get_chat_response(user_query, history):
    trimmed = list(history[-MAX_HISTORY:])
    trimmed.append({"role": "user", "content": user_query})
    return _chat(CHAT_SYSTEM, trimmed)


# ── Investigation Recommendations ──────────────────────────────────────────────

INVESTIGATION_SYSTEM = """You are a medical expert. Based on the patient data and symptoms provided,
recommend the most relevant diagnostic investigations.
Return ONLY a valid JSON object in this exact format, nothing else:
{"investigations": ["Investigation 1", "Investigation 2", "Investigation 3"]}
Order from highest to lowest priority. Maximum 5 items."""


def get_investigation_recommendations(patient_data, symptoms):
    prompt = f"Patient: {patient_data}\nSymptoms: {symptoms}"
    raw = _chat(INVESTIGATION_SYSTEM, [{"role": "user", "content": prompt}], temperature=0.1)
    return _parse_list(raw, "investigations")


# ── Management Recommendations ─────────────────────────────────────────────────

MANAGEMENT_SYSTEM = """You are a medical expert. Based on the patient data, symptoms, and investigations,
recommend the most relevant management plan.
Return ONLY a valid JSON object in this exact format, nothing else:
{"management": ["Step 1", "Step 2", "Step 3"]}
Order from highest to lowest priority. Maximum 5 items."""


def get_management_recommendations(patient_data, symptoms, investigations):
    prompt = f"Patient: {patient_data}\nSymptoms: {symptoms}\nInvestigations: {investigations}"
    raw = _chat(MANAGEMENT_SYSTEM, [{"role": "user", "content": prompt}], temperature=0.1)
    return _parse_list(raw, "management")


# ── Reconsider Management ──────────────────────────────────────────────────────

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
    raw = _chat(RECONSIDER_SYSTEM, [{"role": "user", "content": prompt}], temperature=0.1)
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
