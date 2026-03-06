from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv
from modules.mongodb import (
    register_user, login_user, get_user,
    get_chat_history, append_chat_messages, clear_chat_history,
    register_patient, get_patient, get_all_patients,
    add_investigations, get_investigations, update_investigation_result,
    add_management, get_management, replace_management,
)
from modules.ai import (
    get_chat_response,
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
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    if not all([name, email, password]):
        return jsonify({"error": "name, email and password are required"}), 400
    result = register_user(name, email, password)
    if "error" in result:
        return jsonify(result), 409
    return jsonify(result), 201


@app.post("/auth/login")
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")
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


# ── Chat ───────────────────────────────────────────────────────────────────────

@app.post("/ai_response")
def ai_response():
    data = request.json
    query = data.get("query")
    user_id = data.get("user_id")
    if not query or not user_id:
        return jsonify({"error": "query and user_id are required"}), 400

    try:
        history = get_chat_history(user_id)
        reply = get_chat_response(query, history)
        append_chat_messages(user_id, [
            {"role": "user", "content": query},
            {"role": "assistant", "content": reply},
        ])
        return jsonify({"response": reply})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.delete("/chat/<user_id>")
def clear_chat(user_id):
    clear_chat_history(user_id)
    return jsonify({"message": "Chat history cleared"})


# ── Patients ───────────────────────────────────────────────────────────────────

@app.post("/patients")
def add_patient():
    data = request.json
    required = ["doctor_id", "name", "sex", "age", "symptoms"]
    if not all(data.get(f) for f in required):
        return jsonify({"error": f"Required fields: {required}"}), 400

    try:
        patient_id = register_patient(
            doctor_id=data["doctor_id"],
            name=data["name"],
            sex=data["sex"],
            age=data["age"],
            allergies=data.get("allergies", ""),
            symptoms=data["symptoms"],
            pre_existing_conditions=data.get("pre_existing_conditions", ""),
        )

        patient_data = {
            "name": data["name"], "sex": data["sex"], "age": data["age"],
            "allergies": data.get("allergies", ""),
            "pre_existing_conditions": data.get("pre_existing_conditions", ""),
        }

        # AI generates investigations
        investigations = get_investigation_recommendations(patient_data, data["symptoms"])
        add_investigations(patient_id, investigations)

        # AI generates management plan
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
    patients = get_all_patients(doctor_id)
    return jsonify({"patients": patients})


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

    # Reconsider management with updated results
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
