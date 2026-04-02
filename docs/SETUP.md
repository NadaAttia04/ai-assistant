# Setup Guide

## Prerequisites

| Tool              | Version  | Install                                      |
|-------------------|----------|----------------------------------------------|
| Python            | 3.8+     | https://python.org                           |
| Flutter SDK       | 3.x      | https://flutter.dev/docs/get-started/install |
| Google Gemini Key | Free     | https://aistudio.google.com/app/apikey       |
| MongoDB           | Optional | Atlas (cloud) or local — has JSON fallback   |

---

## 1. Backend Setup

```bash
cd backend
pip install -r requirements.txt
```

### Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
GEMINI_API_KEY=AIza...        # Your Gemini API key (free)
MONGODB_URI=mongodb://localhost:27017/   # optional — see below
FLASK_ENV=development
PORT=5000
```

### Getting a free Gemini API key

1. Go to https://aistudio.google.com/app/apikey
2. Click **"Create API key in new project"**
3. Copy the key (starts with `AIza...`)

> Rate limits on free tier: **10 requests/min**, **250 req/day** per key.
> If you hit limits, generate a new key in a fresh Google project.

### MongoDB (optional)

The backend **automatically falls back to local JSON files** (`backend/data/`) if MongoDB is not reachable — no setup needed for development.

**For production — MongoDB Atlas (free tier):**
1. Create a cluster at https://cloud.mongodb.com
2. Create a database user
3. Copy connection string into `MONGODB_URI`

### Run the backend

```bash
python app.py
# Output: Running on http://0.0.0.0:5000
```

Test:
```bash
curl http://localhost:5000/
# {"message":"AI Assistant API","status":"ok"}
```

---

## 2. Flutter App Setup

```bash
cd flutter_app
flutter pub get
```

### Configure API base URL

Open `lib/core/services/api_service.dart`:

```dart
// Android emulator
static const _base = 'http://10.0.2.2:5000';

// iOS simulator / web / desktop
static const _base = 'http://localhost:5000';

// Physical device — use your machine's local IP (run: ipconfig)
static const _base = 'http://192.168.1.x:5000';
```

### Android firewall (Windows host only)

If the app can't reach the backend from a physical device, allow port 5000 through the Windows firewall:

```
netsh advfirewall firewall add rule name="Flask 5000" dir=in action=allow protocol=TCP localport=5000
```

### Run on Android emulator

```bash
flutter run
```

### Run on a physical Android device (Xiaomi / any)

1. **Settings → About Phone** → tap Build Number 7 times
2. **Settings → Developer Options** → enable:
   - USB Debugging
   - USB Debugging (Security settings) ← required on Xiaomi/HyperOS
   - Install via USB
3. Plug in via USB → tap **Allow** on the phone popup
4. Update `_base` to your machine's local IP
5. Run:

```bash
flutter run -d <device-id>
```

Or build and push manually (if ADB install is restricted):
```bash
flutter build apk --debug
adb push build/app/outputs/flutter-apk/app-debug.apk //sdcard/Download/app.apk
# Then open Files app on phone → Downloads → tap app.apk → Install
```

### Xiaomi / MIUI — Speech Recognition

For voice input (STT) to work on Xiaomi devices, set Google as the default voice recognizer:

**Settings → Manage apps → Default apps → Voice recognition → Google**

### Android build notes

If you get **"not enough disk space"** on C: drive, redirect Gradle cache:

```properties
# android/gradle.properties
GRADLE_USER_HOME=D:/gradle-home
```

If you get **Java heap space** error:

```properties
# android/gradle.properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m
```

---

## 3. Android Config

| Setting | Value |
|---------|-------|
| `minSdk` | 24 |
| `compileSdk` | 36 |
| Kotlin | 2.1.0 |
| Core library desugaring | enabled (`desugar_jdk_libs:2.1.2`) |

**Permissions required:**
- `INTERNET`
- `RECORD_AUDIO` — voice input (STT)
- `READ_MEDIA_IMAGES` — image attachments in chat
- `POST_NOTIFICATIONS` — medication/appointment/order/message alerts
- `RECEIVE_BOOT_COMPLETED` — reschedule reminders after reboot
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` — medication reminders

---

## 4. Environment Variables

| Variable        | Required | Description                                  |
|-----------------|----------|----------------------------------------------|
| `GEMINI_API_KEY`| Yes      | Google Gemini API key (free at AI Studio)    |
| `MONGODB_URI`   | No       | MongoDB URI — falls back to JSON if missing  |
| `FLASK_ENV`     | No       | `development` or `production`                |
| `PORT`          | No       | Backend port (default: 5000)                 |

---

## 5. AI Model Configuration

Models are tried in order until one succeeds (`backend/modules/ai.py`):

```python
MODELS = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
```

The backend automatically retries on 503 (overloaded) and 429 (rate limit), waiting the exact delay Gemini specifies before retrying, then falling back to the next model.
