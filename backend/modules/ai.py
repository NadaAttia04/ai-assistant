import base64
import json
import time
from openai import OpenAI, RateLimitError, APIStatusError
from config import OPENAI_API_KEY

_client = OpenAI(api_key=OPENAI_API_KEY)

MODELS = ["gpt-4o", "gpt-4o-mini"]
MAX_HISTORY = 20
MAX_RETRIES = 3


# ── Low-level OpenAI call ──────────────────────────────────────────────────────

def _call_model(model, system_prompt, messages, temperature):
    response = _client.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": system_prompt}] + messages,
        temperature=temperature,
        timeout=60,
    )
    return response.choices[0].message.content.strip()


def _call_with_retry(system_prompt, messages, temperature=0.3):
    last_error = None
    for model in MODELS:
        for attempt in range(MAX_RETRIES):
            try:
                result = _call_model(model, system_prompt, messages, temperature)
                if model != MODELS[0]:
                    print(f"[AI] Used fallback model: {model}")
                return result
            except RateLimitError as e:
                last_error = e
                wait = 2 ** (attempt + 2)
                print(f"[AI] 429 on {model}, retrying in {wait}s...")
                time.sleep(wait)
                continue
            except APIStatusError as e:
                last_error = e
                if e.status_code in (500, 503):
                    wait = 2 ** (attempt + 2)
                    print(f"[AI] {e.status_code} on {model}, retrying in {wait}s...")
                    time.sleep(wait)
                    continue
                else:
                    break
            except Exception as e:
                last_error = e
                break
    raise Exception("The AI service is currently unavailable after multiple retries. Please try again in a few seconds.")


def _history_to_messages(history):
    messages = []
    for m in history:
        role = "assistant" if m["role"] == "assistant" else "user"
        messages.append({"role": role, "content": m["content"]})
    return messages


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
    messages = _history_to_messages(trimmed)
    raw = _call_with_retry(_build_chat_system(role), messages)
    text, severity = _parse_severity(raw)
    return text, severity


# ── Attachment chat (image OR file) ───────────────────────────────────────────

def get_chat_response_with_attachment(text, data_bytes, mime_type, history, role="patient"):
    """Handle any binary attachment (image or PDF) alongside optional text."""
    trimmed = list(history[-MAX_HISTORY:])
    messages = _history_to_messages(trimmed)
    user_content = []
    if mime_type.startswith("image/"):
        b64 = base64.b64encode(data_bytes).decode("utf-8")
        prompt_text = text if text else "Please analyze this medical image and describe your findings in detail."
        user_content.append({"type": "text", "text": prompt_text})
        user_content.append({
            "type": "image_url",
            "image_url": {"url": f"data:{mime_type};base64,{b64}"},
        })
    else:
        # Non-image files: extract text and send as text content
        try:
            from pypdf import PdfReader
            import io
            reader = PdfReader(io.BytesIO(data_bytes))
            pdf_text = "\n".join(page.extract_text() or "" for page in reader.pages)
            prompt_text = text if text else "Please analyze this medical document and summarize the findings."
            user_content.append({"type": "text", "text": f"{prompt_text}\n\n[Attached file content]:\n{pdf_text}"})
        except Exception:
            prompt_text = text if text else "Please analyze this attached medical file."
            user_content.append({"type": "text", "text": prompt_text})
    messages.append({"role": "user", "content": user_content})
    raw = _call_with_retry(_build_chat_system(role), messages)
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
        [{"role": "user", "content": prompt}],
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
        [{"role": "user", "content": prompt}],
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
        [{"role": "user", "content": prompt}],
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
        [{"role": "user", "content": prompt}],
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
