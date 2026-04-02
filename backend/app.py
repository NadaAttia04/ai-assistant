import os
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
from modules.mongodb import (
    register_user, login_user, get_user, update_user, change_password,
    check_email_exists,
    # Legacy single-session chat
    get_chat_history, append_chat_messages, clear_chat_history,
    # Multi-session chat
    create_chat_session, get_chat_sessions, get_session_messages,
    append_to_session, update_session_title, delete_chat_session,
    # Patients
    register_patient, get_patient, get_all_patients,
    add_investigations, get_investigations, update_investigation_result,
    add_management, get_management, replace_management,
    # Consultation chat
    get_or_create_consultation, get_consultation_messages,
    send_consultation_message, get_consultations_for_patient,
    get_consultations_for_doctor,
)
from modules.services_data import DOCTORS, MEDICINES, APPOINTMENTS, PENDING_PATIENTS
from modules.ai import (
    get_chat_response,
    get_chat_response_with_attachment,
    get_chat_response_with_image,  # legacy alias
    generate_medical_report,
    get_investigation_recommendations,
    get_management_recommendations,
    reconsider_management,
)

load_dotenv()

app = Flask(__name__)
CORS(app)


# ── Health ─────────────────────────────────────────────────────────────────────

@app.get("/")
def index():
    return jsonify({"message": "AI Assistant API", "status": "ok"})


# ── Auth ───────────────────────────────────────────────────────────────────────

@app.post("/auth/register")
def register():
    data = request.json
    name, email, password = data.get("name"), data.get("email"), data.get("password")
    if not all([name, email, password]):
        return jsonify({"error": "name, email and password are required"}), 400
    result = register_user(name, email, password)
    if "error" in result:
        return jsonify(result), 409
    return jsonify(result), 201


@app.post("/auth/login")
def login():
    data = request.json
    email, password = data.get("email"), data.get("password")
    if not all([email, password]):
        return jsonify({"error": "email and password are required"}), 400
    result = login_user(email, password)
    if "error" in result:
        return jsonify(result), 401
    return jsonify(result)


@app.get("/users/<user_id>")
def get_user_profile(user_id):
    user = get_user(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user)


@app.put("/users/<user_id>")
def update_user_profile(user_id):
    data = request.json or {}
    result = update_user(user_id, data)
    if "error" in result:
        return jsonify(result), 400
    return jsonify(result)


@app.post("/users/<user_id>/avatar")
def upload_avatar(user_id):
    image_file = request.files.get("avatar")
    if not image_file:
        return jsonify({"error": "avatar file required"}), 400
    avatar_dir = os.path.join(os.path.dirname(__file__), "static", "avatars")
    os.makedirs(avatar_dir, exist_ok=True)
    ext = image_file.filename.rsplit(".", 1)[-1].lower() if "." in (image_file.filename or "") else "jpg"
    filename = f"{user_id}.{ext}"
    save_path = os.path.join(avatar_dir, filename)
    image_file.save(save_path)
    avatar_url = f"/avatars/{filename}"
    update_user(user_id, {"avatar_url": avatar_url})
    return jsonify({"avatar_url": avatar_url})


@app.get("/avatars/<filename>")
def serve_avatar(filename):
    avatar_dir = os.path.join(os.path.dirname(__file__), "static", "avatars")
    return send_from_directory(avatar_dir, filename)


@app.post("/auth/change_password")
def route_change_password():
    data = request.json
    user_id = data.get("user_id")
    current = data.get("current_password")
    new_pwd = data.get("new_password")
    if not all([user_id, current, new_pwd]):
        return jsonify({"error": "user_id, current_password, new_password required"}), 400
    result = change_password(user_id, current, new_pwd)
    if "error" in result:
        return jsonify(result), 400
    return jsonify(result)


@app.post("/auth/forgot_password")
def forgot_password():
    data = request.json
    email = data.get("email", "").strip()
    if not email:
        return jsonify({"error": "email is required"}), 400
    if not check_email_exists(email):
        return jsonify({"error": "No account found with this email address"}), 404
    # In production: send password reset email here
    return jsonify({"message": "Password reset instructions sent to your email"})


# ── Consultation Chat ───────────────────────────────────────────────────────────

@app.post("/consultations")
def create_consultation():
    data = request.json
    patient_id = data.get("patient_id", "").strip()
    doctor_id = data.get("doctor_id", "").strip()
    patient_name = data.get("patient_name", "Patient")
    doctor_name = data.get("doctor_name", "Doctor")
    if not patient_id or not doctor_id:
        return jsonify({"error": "patient_id and doctor_id required"}), 400
    result = get_or_create_consultation(patient_id, doctor_id, patient_name, doctor_name)
    return jsonify(result), 201


@app.get("/consultations/<room_id>/messages")
def fetch_consultation_messages(room_id):
    msgs = get_consultation_messages(room_id)
    return jsonify({"messages": msgs})


@app.post("/consultations/<room_id>/message")
def post_consultation_message(room_id):
    data = request.json
    sender_role = data.get("sender_role", "patient")
    sender_name = data.get("sender_name", "")
    content = data.get("content", "").strip()
    if not content:
        return jsonify({"error": "content required"}), 400
    msg = send_consultation_message(room_id, sender_role, sender_name, content)
    return jsonify({"message": msg}), 201


@app.get("/consultations/patient/<patient_id>")
def list_patient_consultations(patient_id):
    rooms = get_consultations_for_patient(patient_id)
    return jsonify({"consultations": rooms})


@app.get("/consultations/doctor/<doctor_id>")
def list_doctor_consultations(doctor_id):
    rooms = get_consultations_for_doctor(doctor_id)
    return jsonify({"consultations": rooms})


# ── Legacy chat (single-session, kept for backward compat) ─────────────────────

@app.post("/ai_response")
def ai_response():
    data = request.json
    query = data.get("query")
    user_id = data.get("user_id")
    if not query or not user_id:
        return jsonify({"error": "query and user_id are required"}), 400
    try:
        history = get_chat_history(user_id)
        reply, _ = get_chat_response(query, history)
        append_chat_messages(user_id, [
            {"role": "user", "content": query},
            {"role": "assistant", "content": reply},
        ])
        return jsonify({"response": reply})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.post("/ai_response_multimodal")
def ai_response_multimodal():
    query = request.form.get("query", "").strip()
    user_id = request.form.get("user_id", "").strip()
    image_file = request.files.get("image")
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
    if not query and not image_file:
        return jsonify({"error": "query or image is required"}), 400
    try:
        history = get_chat_history(user_id)
        if image_file:
            reply = get_chat_response_with_image(
                query, image_file.read(),
                image_file.content_type or "image/jpeg", history
            )
        else:
            reply = get_chat_response(query, history)
        stored_q = query if query else "[image]"
        append_chat_messages(user_id, [
            {"role": "user", "content": stored_q},
            {"role": "assistant", "content": reply},
        ])
        return jsonify({"response": reply})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.delete("/chat/<user_id>")
def clear_chat(user_id):
    clear_chat_history(user_id)
    return jsonify({"message": "Chat history cleared"})


# ── Chat Sessions ──────────────────────────────────────────────────────────────

@app.post("/chats/<user_id>/new")
def new_chat_session(user_id):
    chat_id = create_chat_session(user_id)
    return jsonify({"chat_id": chat_id}), 201


@app.get("/chats/<user_id>")
def list_chat_sessions(user_id):
    sessions = get_chat_sessions(user_id)
    return jsonify({"sessions": sessions})


@app.get("/chats/session/<chat_id>")
def get_chat_session_messages(chat_id):
    messages = get_session_messages(chat_id)
    return jsonify({"messages": messages})


@app.delete("/chats/session/<chat_id>")
def remove_chat_session(chat_id):
    delete_chat_session(chat_id)
    return jsonify({"message": "Session deleted"})


# ── Session-based chat endpoints ───────────────────────────────────────────────

@app.post("/chat")
def chat():
    data = request.json
    query = data.get("query", "").strip()
    user_id = data.get("user_id", "").strip()
    chat_id = data.get("chat_id", "").strip()
    role = data.get("role", "patient")
    if not all([query, user_id, chat_id]):
        return jsonify({"error": "query, user_id and chat_id are required"}), 400
    try:
        history = get_session_messages(chat_id)
        reply, severity = get_chat_response(query, history, role)
        append_to_session(chat_id, [
            {"role": "user", "content": query},
            {"role": "assistant", "content": reply},
        ])
        if not history:
            update_session_title(chat_id, query)
        return jsonify({"response": reply, "severity": severity})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.post("/analyze_image")
def analyze_image():
    query = request.form.get("query", "").strip()
    user_id = request.form.get("user_id", "").strip()
    chat_id = request.form.get("chat_id", "").strip()
    role = request.form.get("role", "patient")
    image_file = request.files.get("image")
    if not user_id or not chat_id or not image_file:
        return jsonify({"error": "user_id, chat_id and image are required"}), 400
    try:
        history = get_session_messages(chat_id)
        reply, severity = get_chat_response_with_attachment(
            query, image_file.read(),
            image_file.content_type or "image/jpeg", history, role
        )
        stored_q = query if query else "[image]"
        append_to_session(chat_id, [
            {"role": "user", "content": stored_q},
            {"role": "assistant", "content": reply},
        ])
        if not history:
            update_session_title(chat_id, query or "Image Analysis")
        return jsonify({"response": reply, "severity": severity})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.post("/upload_file")
def upload_file():
    query = request.form.get("query", "").strip()
    user_id = request.form.get("user_id", "").strip()
    chat_id = request.form.get("chat_id", "").strip()
    role = request.form.get("role", "patient")
    uploaded = request.files.get("file")
    if not user_id or not chat_id or not uploaded:
        return jsonify({"error": "user_id, chat_id and file are required"}), 400
    try:
        history = get_session_messages(chat_id)
        reply, severity = get_chat_response_with_attachment(
            query, uploaded.read(),
            uploaded.content_type or "application/pdf", history, role
        )
        stored_q = query if query else f"[file: {uploaded.filename}]"
        append_to_session(chat_id, [
            {"role": "user", "content": stored_q},
            {"role": "assistant", "content": reply},
        ])
        if not history:
            update_session_title(chat_id, query or uploaded.filename or "File Analysis")
        return jsonify({"response": reply, "severity": severity})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.post("/generate_report")
def generate_report():
    data = request.json
    messages = data.get("messages", [])
    role = data.get("role", "patient")
    if not messages:
        return jsonify({"error": "messages are required"}), 400
    try:
        report = generate_medical_report(messages, role)
        return jsonify({"report": report})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Services ───────────────────────────────────────────────────────────────────

@app.get("/doctors")
def get_doctors():
    specialty = request.args.get("specialty", "").strip().lower()
    if specialty and specialty != "all":
        filtered = [d for d in DOCTORS if specialty in d["specialty"].lower()]
    else:
        filtered = DOCTORS
    return jsonify({"doctors": filtered})


@app.get("/medicines")
def get_medicines():
    category = request.args.get("category", "").strip().lower()
    if category and category != "all":
        filtered = [m for m in MEDICINES if category in m["category"].lower()]
    else:
        filtered = MEDICINES
    return jsonify({"medicines": filtered})


@app.get("/appointments")
def get_appointments():
    doctor_id = request.args.get("doctor_id", "").strip()
    status = request.args.get("status", "").strip().lower()
    result = APPOINTMENTS
    if doctor_id:
        result = [a for a in result if a["doctor_id"] == doctor_id]
    if status and status != "all":
        result = [a for a in result if a["status"] == status]
    return jsonify({"appointments": result})


@app.get("/pending_patients")
def get_pending_patients():
    return jsonify({"patients": PENDING_PATIENTS})


# ── Patients ───────────────────────────────────────────────────────────────────

@app.post("/patients")
def add_patient():
    data = request.json
    required = ["doctor_id", "name", "sex", "age", "symptoms"]
    if not all(data.get(f) for f in required):
        return jsonify({"error": f"Required fields: {required}"}), 400
    try:
        patient_id = register_patient(
            doctor_id=data["doctor_id"], name=data["name"], sex=data["sex"],
            age=data["age"], allergies=data.get("allergies", ""),
            symptoms=data["symptoms"],
            pre_existing_conditions=data.get("pre_existing_conditions", ""),
        )
        patient_data = {
            "name": data["name"], "sex": data["sex"], "age": data["age"],
            "allergies": data.get("allergies", ""),
            "pre_existing_conditions": data.get("pre_existing_conditions", ""),
        }
        investigations = get_investigation_recommendations(patient_data, data["symptoms"])
        add_investigations(patient_id, investigations)
        management = get_management_recommendations(patient_data, data["symptoms"], investigations)
        add_management(patient_id, management)
        return jsonify({"patient_id": patient_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.get("/patients/<patient_id>")
def fetch_patient(patient_id):
    patient = get_patient(patient_id)
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    return jsonify(patient)


@app.get("/patients/doctor/<doctor_id>")
def fetch_all_patients(doctor_id):
    return jsonify({"patients": get_all_patients(doctor_id)})


# ── Investigations ─────────────────────────────────────────────────────────────

@app.get("/patients/<patient_id>/investigations")
def fetch_investigations(patient_id):
    return jsonify({"investigations": get_investigations(patient_id)})


@app.put("/investigations/<investigation_id>")
def update_result(investigation_id):
    data = request.json
    result = data.get("result")
    patient_id = data.get("patient_id")
    if result is None or not patient_id:
        return jsonify({"error": "result and patient_id are required"}), 400
    if not update_investigation_result(investigation_id, result):
        return jsonify({"error": "Investigation not found"}), 404
    try:
        patient = get_patient(patient_id)
        investigations = get_investigations(patient_id)
        current_mgmt = [m["text"] for m in get_management(patient_id)]
        new_mgmt = reconsider_management(patient, investigations, current_mgmt)
        replace_management(patient_id, new_mgmt)
        return jsonify({"message": "Result saved, management updated", "management": new_mgmt})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Management ─────────────────────────────────────────────────────────────────

@app.get("/patients/<patient_id>/management")
def fetch_management(patient_id):
    return jsonify({"management": get_management(patient_id)})


# ── Run ────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    from config import PORT
    app.run(host="0.0.0.0", port=PORT, debug=True)
