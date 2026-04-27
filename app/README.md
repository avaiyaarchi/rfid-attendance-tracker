# Smart Attendance System
**RFID → Arduino → Python → Firebase → Flutter**

Real-time student attendance tracking using RFID cards. When a student scans their card, the UID flows through Arduino → Python middleware → Firebase → and appears instantly in the Flutter mobile app.

---

## System Overview

```
[Student scans card]
      ↓
[Arduino + MFRC522]  — reads UID via SPI, sends over Serial (USB)
      ↓
[Python Middleware]  — reads serial, looks up student, pushes to Firestore
      ↓
[Firebase Firestore] — stores record, triggers real-time listeners
      ↓
[Flutter Mobile App] — StreamBuilder updates UI instantly
```

---

## Project Structure

```
smart_attendance/
├── arduino/
│   └── rfid_scanner.ino        ← Upload to Arduino
├── python_middleware/
│   ├── middleware.py            ← Run on PC/Raspberry Pi
│   └── requirements.txt
├── firebase/
│   └── firestore.rules         ← Paste into Firebase Console
└── flutter_app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        └── pages/
            ├── home_shell.dart
            ├── login_page.dart
            ├── dashboard_page.dart
            ├── live_attendance_page.dart
            ├── student_list_page.dart
            ├── class_management_page.dart
            └── reports_page.dart
```

---

## Step-by-Step Setup

### 1. Firebase Project

1. Go to https://console.firebase.google.com → Create project
2. Enable **Authentication** → Sign-in method → Email/Password
3. Enable **Firestore Database** (production mode)
4. Paste `firestore/firestore.rules` into the Rules tab
5. Go to Project Settings → Service Accounts → **Generate new private key**
   - Save as `python_middleware/serviceAccountKey.json`
6. Go to Project Settings → Your apps → Add Android/iOS app
   - Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   - Place in `flutter_app/android/app/` or `flutter_app/ios/Runner/`

### 2. Firestore Collections (create manually or let middleware create them)

```
students/
  {id}: { name, roll_no, rfid_uid, class_id, photo_url, created_at }

attendance_logs/
  {id}: { uid, timestamp, date, time, status, valid, student_id, student_name }

classes/
  {id}: { name, teacher, student_ids[], created_at }

users/
  {uid}: { email, role }   ← role = 'admin' or 'teacher'
```

Create your first admin user:
- Create user in Firebase Auth Console
- Add document in Firestore: `users/{uid}` → `{ role: "admin" }`

### 3. Arduino Hardware Wiring

| MFRC522 Pin | Arduino Uno Pin |
|-------------|-----------------|
| SDA         | 10              |
| SCK         | 13              |
| MOSI        | 11              |
| MISO        | 12              |
| RST         | 9               |
| GND         | GND             |
| 3.3V        | 3.3V ← NOT 5V  |

Green LED → Pin 7 (with 220Ω resistor to GND)

**Library:** Install `MFRC522` by GithubCommunity via Arduino Library Manager.

Upload `arduino/rfid_scanner.ino` to your Arduino.

### 4. Python Middleware

```bash
cd python_middleware
pip install -r requirements.txt

# Edit middleware.py — set SERIAL_PORT:
# Windows:  "COM3"  (check Device Manager)
# Linux:    "/dev/ttyUSB0"
# macOS:    "/dev/tty.usbserial-XXXX"

python middleware.py
```

You should see:
```
2024-01-15 09:30:00 [INFO] Firebase initialized successfully.
2024-01-15 09:30:01 [INFO] Serial port /dev/ttyUSB0 opened at 9600 baud.
2024-01-15 09:30:01 [INFO] Listening for RFID scans... Press Ctrl+C to stop.
```

### 5. Flutter Mobile App

```bash
cd flutter_app
flutter pub get

# Add google-services.json (Android) or GoogleService-Info.plist (iOS)
# then:

flutter run
```

**Required Flutter packages** (already in pubspec.yaml):
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `provider`, `fl_chart`, `google_fonts`
- `pdf`, `excel`, `share_plus`

---

## Adding Students

1. Open the app → Students tab → Add button
2. Fill in: Name, Roll Number, RFID UID, Class
3. To get a student's UID: scan their card while middleware is running — the UID prints in the terminal
4. Copy the UID into the student profile

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Serial port not found | Run `python -m serial.tools.list_ports` to list available ports |
| Firebase permission denied | Check Firestore rules; ensure middleware uses Admin SDK (bypasses rules) |
| Card not detected | Check MFRC522 wiring; ensure 3.3V not 5V |
| Flutter app blank | Ensure `google-services.json` is in `android/app/` |
| Duplicate logs | Adjust `DEBOUNCE_SEC` in `middleware.py` |

---

## Security Notes

- `serviceAccountKey.json` has full admin access — **never commit to Git**
- Add `serviceAccountKey.json` to `.gitignore`
- Firebase security rules restrict read/write to authenticated users only
- The Python middleware uses Admin SDK which bypasses client-side rules (intentional)

---

## License

MIT — free to use and modify for educational/commercial projects.
