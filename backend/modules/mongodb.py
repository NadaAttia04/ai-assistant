"""
Database layer with automatic fallback:
- If MongoDB is reachable → uses MongoDB
- Otherwise → uses local JSON files in ./data/ (good for development/testing)
"""
import json
import os
import uuid
from datetime import datetime

# ── Try connecting to MongoDB ──────────────────────────────────────────────────
_USE_MONGO = False
_db = None

try:
    from pymongo import MongoClient
    from bson import ObjectId
    from config import MONGODB_URI
    _client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=2000)
    _client.server_info()
    _db = _client["ai_assistant"]
    _USE_MONGO = True
    print("[DB] Connected to MongoDB")
except Exception as e:
    print(f"[DB] MongoDB not available ({e}). Using local JSON storage.")


# ── JSON file storage (fallback) ───────────────────────────────────────────────

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
os.makedirs(DATA_DIR, exist_ok=True)


def _load(collection):
    path = os.path.join(DATA_DIR, f"{collection}.json")
    if not os.path.exists(path):
        return []
    with open(path, "r") as f:
        return json.load(f)


def _save(collection, data):
    path = os.path.join(DATA_DIR, f"{collection}.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def _new_id():
    return str(uuid.uuid4())


# ── Users ──────────────────────────────────────────────────────────────────────

def register_user(name, email, password):
    if _USE_MONGO:
        users = _db.users
        if users.find_one({"email": email}):
            return {"error": "Email already registered"}
        user_id = users.insert_one({"name": name, "email": email, "password": password}).inserted_id
        return {"user_id": str(user_id)}
    else:
        users = _load("users")
        if any(u["email"] == email for u in users):
            return {"error": "Email already registered"}
        user = {"_id": _new_id(), "name": name, "email": email, "password": password, "phone": "", "age": "", "address": "", "city": "", "governorate": "", "avatar_url": ""}
        users.append(user)
        _save("users", users)
        return {"user_id": user["_id"]}


def login_user(email, password):
    if _USE_MONGO:
        user = _db.users.find_one({"email": email})
        if not user:
            return {"error": "User not found"}
        if user["password"] != password:
            return {"error": "Invalid credentials"}
        return {"user_id": str(user["_id"]), "name": user["name"]}
    else:
        users = _load("users")
        user = next((u for u in users if u["email"] == email), None)
        if not user:
            return {"error": "User not found"}
        if user["password"] != password:
            return {"error": "Invalid credentials"}
        return {"user_id": user["_id"], "name": user["name"]}


def get_user(user_id):
    if _USE_MONGO:
        user = _db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            return None
        user["_id"] = str(user["_id"])
        user.pop("password", None)
        return user
    else:
        users = _load("users")
        user = next((u for u in users if u["_id"] == user_id), None)
        if user:
            user = dict(user)
            user.pop("password", None)
        return user


# ── Legacy Chat History (single session per user) ──────────────────────────────
# Kept for backward compat with /ai_response endpoint used by patient flow.

def get_chat_history(user_id):
    if _USE_MONGO:
        record = _db.chat_history.find_one({"user_id": user_id})
        return record["messages"] if record and "messages" in record else []
    else:
        history = _load("chat_history")
        record = next((h for h in history if h["user_id"] == user_id), None)
        return record["messages"] if record else []


def append_chat_messages(user_id, messages):
    if _USE_MONGO:
        _db.chat_history.update_one(
            {"user_id": user_id},
            {"$push": {"messages": {"$each": messages}}},
            upsert=True,
        )
    else:
        history = _load("chat_history")
        record = next((h for h in history if h["user_id"] == user_id), None)
        if record:
            record["messages"].extend(messages)
        else:
            history.append({"user_id": user_id, "messages": messages})
        _save("chat_history", history)


def clear_chat_history(user_id):
    if _USE_MONGO:
        _db.chat_history.delete_one({"user_id": user_id})
    else:
        history = _load("chat_history")
        history = [h for h in history if h["user_id"] != user_id]
        _save("chat_history", history)


# ── Chat Sessions (multi-session per user) ─────────────────────────────────────

def create_chat_session(user_id):
    now = datetime.utcnow().isoformat()
    if _USE_MONGO:
        result = _db.chat_sessions.insert_one({
            "user_id": user_id, "title": "New Chat",
            "created_at": now, "messages": [],
        })
        return str(result.inserted_id)
    else:
        sessions = _load("chat_sessions")
        sid = _new_id()
        sessions.append({
            "_id": sid, "user_id": user_id, "title": "New Chat",
            "created_at": now, "messages": [],
        })
        _save("chat_sessions", sessions)
        return sid


def get_chat_sessions(user_id):
    """Returns session metadata list (no messages), newest first."""
    if _USE_MONGO:
        items = list(_db.chat_sessions.find(
            {"user_id": user_id}, {"messages": 0}
        ).sort("created_at", -1))
        for s in items:
            s["_id"] = str(s["_id"])
        return items
    else:
        sessions = _load("chat_sessions")
        result = [
            {k: v for k, v in s.items() if k != "messages"}
            for s in sessions if s["user_id"] == user_id
        ]
        return sorted(result, key=lambda x: x.get("created_at", ""), reverse=True)


def get_session_messages(chat_id):
    if _USE_MONGO:
        s = _db.chat_sessions.find_one({"_id": ObjectId(chat_id)})
        return s["messages"] if s else []
    else:
        sessions = _load("chat_sessions")
        s = next((x for x in sessions if x["_id"] == chat_id), None)
        return s["messages"] if s else []


def append_to_session(chat_id, messages):
    if _USE_MONGO:
        _db.chat_sessions.update_one(
            {"_id": ObjectId(chat_id)},
            {"$push": {"messages": {"$each": messages}}},
        )
    else:
        sessions = _load("chat_sessions")
        for s in sessions:
            if s["_id"] == chat_id:
                s["messages"].extend(messages)
                break
        _save("chat_sessions", sessions)


def update_session_title(chat_id, title):
    title = (title[:47] + "...") if len(title) > 50 else title
    if _USE_MONGO:
        _db.chat_sessions.update_one(
            {"_id": ObjectId(chat_id)}, {"$set": {"title": title}}
        )
    else:
        sessions = _load("chat_sessions")
        for s in sessions:
            if s["_id"] == chat_id:
                s["title"] = title
                break
        _save("chat_sessions", sessions)


def delete_chat_session(chat_id):
    if _USE_MONGO:
        _db.chat_sessions.delete_one({"_id": ObjectId(chat_id)})
    else:
        sessions = _load("chat_sessions")
        _save("chat_sessions", [s for s in sessions if s["_id"] != chat_id])


# ── Patients ───────────────────────────────────────────────────────────────────

def register_patient(doctor_id, name, sex, age, allergies, symptoms, pre_existing_conditions):
    if _USE_MONGO:
        patient_id = _db.patients.insert_one({
            "doctor_id": ObjectId(doctor_id),
            "name": name, "sex": sex, "age": age,
            "allergies": allergies, "symptoms": symptoms,
            "pre_existing_conditions": pre_existing_conditions,
        }).inserted_id
        return str(patient_id)
    else:
        patients = _load("patients")
        pid = _new_id()
        patients.append({
            "_id": pid, "doctor_id": doctor_id, "name": name, "sex": sex,
            "age": age, "allergies": allergies, "symptoms": symptoms,
            "pre_existing_conditions": pre_existing_conditions,
        })
        _save("patients", patients)
        return pid


def get_patient(patient_id):
    if _USE_MONGO:
        patient = _db.patients.find_one({"_id": ObjectId(patient_id)})
        if not patient:
            return None
        patient["_id"] = str(patient["_id"])
        patient["doctor_id"] = str(patient["doctor_id"])
        return patient
    else:
        patients = _load("patients")
        return next((p for p in patients if p["_id"] == patient_id), None)


def get_all_patients(doctor_id):
    if _USE_MONGO:
        patients = list(_db.patients.find({"doctor_id": ObjectId(doctor_id)}))
        for p in patients:
            p["_id"] = str(p["_id"])
            p["doctor_id"] = str(p["doctor_id"])
        return patients
    else:
        patients = _load("patients")
        return [p for p in patients if p["doctor_id"] == doctor_id]


# ── Investigations ─────────────────────────────────────────────────────────────

def add_investigations(patient_id, items):
    if _USE_MONGO:
        docs = [{"patient_id": ObjectId(patient_id), "text": item, "result": None} for item in items]
        if docs:
            _db.investigations.insert_many(docs)
    else:
        investigations = _load("investigations")
        for item in items:
            investigations.append({"_id": _new_id(), "patient_id": patient_id, "text": item, "result": None})
        _save("investigations", investigations)


def get_investigations(patient_id):
    if _USE_MONGO:
        data = list(_db.investigations.find({"patient_id": ObjectId(patient_id)}))
        for d in data:
            d["_id"] = str(d["_id"])
            d["patient_id"] = str(d["patient_id"])
        return data
    else:
        investigations = _load("investigations")
        return [i for i in investigations if i["patient_id"] == patient_id]


def update_investigation_result(investigation_id, result):
    if _USE_MONGO:
        res = _db.investigations.update_one(
            {"_id": ObjectId(investigation_id)},
            {"$set": {"result": result}},
        )
        return res.modified_count > 0
    else:
        investigations = _load("investigations")
        for inv in investigations:
            if inv["_id"] == investigation_id:
                inv["result"] = result
                _save("investigations", investigations)
                return True
        return False


# ── Management ─────────────────────────────────────────────────────────────────

def add_management(patient_id, items):
    if _USE_MONGO:
        docs = [{"patient_id": ObjectId(patient_id), "text": item} for item in items]
        if docs:
            _db.management.insert_many(docs)
    else:
        management = _load("management")
        for item in items:
            management.append({"_id": _new_id(), "patient_id": patient_id, "text": item})
        _save("management", management)


def get_management(patient_id):
    if _USE_MONGO:
        data = list(_db.management.find({"patient_id": ObjectId(patient_id)}))
        for d in data:
            d["_id"] = str(d["_id"])
            d["patient_id"] = str(d["patient_id"])
        return data
    else:
        management = _load("management")
        return [m for m in management if m["patient_id"] == patient_id]


def replace_management(patient_id, items):
    if _USE_MONGO:
        _db.management.delete_many({"patient_id": ObjectId(patient_id)})
        add_management(patient_id, items)
    else:
        management = _load("management")
        management = [m for m in management if m["patient_id"] != patient_id]
        _save("management", management)
        add_management(patient_id, items)


# ── User profile update ─────────────────────────────────────────────────────────

def check_email_exists(email):
    if _USE_MONGO:
        return _db.users.find_one({"email": email}) is not None
    else:
        users = _load("users")
        return any(u["email"] == email for u in users)


def update_user(user_id, fields: dict):
    """Update allowed profile fields. Returns updated user or error."""
    allowed = {"name", "phone", "age", "address", "city", "governorate", "avatar_url"}
    update_data = {k: v for k, v in fields.items() if k in allowed and v is not None}
    if not update_data:
        return {"error": "No valid fields to update"}
    if _USE_MONGO:
        res = _db.users.update_one({"_id": ObjectId(user_id)}, {"$set": update_data})
        if res.matched_count == 0:
            return {"error": "User not found"}
        return {"message": "Profile updated"}
    else:
        users = _load("users")
        for u in users:
            if u["_id"] == user_id:
                u.update(update_data)
                _save("users", users)
                return {"message": "Profile updated"}
        return {"error": "User not found"}


def change_password(user_id, current_password, new_password):
    if _USE_MONGO:
        user = _db.users.find_one({"_id": ObjectId(user_id)})
        if not user:
            return {"error": "User not found"}
        if user["password"] != current_password:
            return {"error": "Current password is incorrect"}
        _db.users.update_one({"_id": ObjectId(user_id)}, {"$set": {"password": new_password}})
        return {"message": "Password changed"}
    else:
        users = _load("users")
        for u in users:
            if u["_id"] == user_id:
                if u["password"] != current_password:
                    return {"error": "Current password is incorrect"}
                u["password"] = new_password
                _save("users", users)
                return {"message": "Password changed"}
        return {"error": "User not found"}


# ── Consultation Chat (patient ↔ doctor direct messages) ──────────────────────

def get_or_create_consultation(patient_id, doctor_id, patient_name, doctor_name):
    """Returns {room_id, created}."""
    now = datetime.utcnow().isoformat()
    if _USE_MONGO:
        room = _db.consultations.find_one(
            {"patient_id": patient_id, "doctor_id": doctor_id}
        )
        if room:
            return {"room_id": str(room["_id"]), "created": False}
        result = _db.consultations.insert_one({
            "patient_id": patient_id, "doctor_id": doctor_id,
            "patient_name": patient_name, "doctor_name": doctor_name,
            "created_at": now, "messages": [],
        })
        return {"room_id": str(result.inserted_id), "created": True}
    else:
        rooms = _load("consultations")
        room = next(
            (r for r in rooms if r["patient_id"] == patient_id and r["doctor_id"] == doctor_id),
            None
        )
        if room:
            return {"room_id": room["_id"], "created": False}
        rid = _new_id()
        rooms.append({
            "_id": rid, "patient_id": patient_id, "doctor_id": doctor_id,
            "patient_name": patient_name, "doctor_name": doctor_name,
            "created_at": now, "messages": [],
        })
        _save("consultations", rooms)
        return {"room_id": rid, "created": True}


def get_consultation_messages(room_id):
    if _USE_MONGO:
        room = _db.consultations.find_one({"_id": ObjectId(room_id)})
        return room["messages"] if room else []
    else:
        rooms = _load("consultations")
        room = next((r for r in rooms if r["_id"] == room_id), None)
        return room["messages"] if room else []


def send_consultation_message(room_id, sender_role, sender_name, content):
    """sender_role: 'patient' or 'doctor'"""
    msg = {
        "_id": _new_id(),
        "sender_role": sender_role,
        "sender_name": sender_name,
        "content": content,
        "timestamp": datetime.utcnow().isoformat(),
    }
    if _USE_MONGO:
        _db.consultations.update_one(
            {"_id": ObjectId(room_id)},
            {"$push": {"messages": msg}},
        )
    else:
        rooms = _load("consultations")
        for r in rooms:
            if r["_id"] == room_id:
                r["messages"].append(msg)
                break
        _save("consultations", rooms)
    return msg


def get_consultations_for_patient(patient_id):
    if _USE_MONGO:
        rooms = list(_db.consultations.find({"patient_id": patient_id}, {"messages": 0}))
        for r in rooms:
            r["_id"] = str(r["_id"])
        return rooms
    else:
        rooms = _load("consultations")
        return [
            {k: v for k, v in r.items() if k != "messages"}
            for r in rooms if r["patient_id"] == patient_id
        ]


def get_consultations_for_doctor(doctor_id):
    if _USE_MONGO:
        rooms = list(_db.consultations.find({"doctor_id": doctor_id}, {"messages": 0}))
        for r in rooms:
            r["_id"] = str(r["_id"])
        return rooms
    else:
        rooms = _load("consultations")
        return [
            {k: v for k, v in r.items() if k != "messages"}
            for r in rooms if r["doctor_id"] == doctor_id
        ]
