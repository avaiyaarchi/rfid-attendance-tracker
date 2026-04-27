"""
Smart Attendance System — Python Middleware
Reads RFID UIDs from Arduino via Serial, pushes to Firebase Firestore.

Requirements:
  pip install pyserial firebase-admin

Setup:
  1. Download serviceAccountKey.json from Firebase Console →
     Project Settings → Service Accounts → Generate new private key
  2. Set SERIAL_PORT below (e.g. COM3 on Windows, /dev/ttyUSB0 on Linux)
  3. Run: python middleware.py
"""

import serial
import time
import sys
import logging
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone

# ─── CONFIG ────────────────────────────────────────────────────────────────────
SERIAL_PORT   = "'COM3'"   # Windows: "COM3" | macOS: "/dev/tty.usbserial-..."
BAUD_RATE     = 9600
SERVICE_KEY   = "serviceAccountkey.json"
DEBOUNCE_SEC  = 60  # Ignore same UID scanned within this many seconds
# ───────────────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)


def init_firebase():
    """Initialize Firebase Admin SDK."""
    cred = credentials.Certificate(SERVICE_KEY)
    firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://smartattendance-6f84f-default-rtdb.firebaseio.com/'
})
    db = firestore.client()
    log.info("Firebase initialized successfully.")
    return db


def init_serial(port: str, baud: int) -> serial.Serial:
    """Open serial connection to Arduino."""
    try:
        ser = serial.Serial(port, baud, timeout=2)
        time.sleep(2)  # Wait for Arduino reset
        log.info(f"Serial port {port} opened at {baud} baud.")
        return ser
    except serial.SerialException as e:
        log.error(f"Cannot open serial port {port}: {e}")
        log.error("Available ports: try 'python -m serial.tools.list_ports'")
        sys.exit(1)


def lookup_student(db, uid: str) -> dict | None:
    """Look up student by RFID UID in Firestore."""
    students = db.collection("students").where("rfid_uid", "==", uid).limit(1).get()
    if students:
        s = students[0].to_dict()
        s["id"] = students[0].id
        return s
    return None


def push_attendance(db, uid: str, student: dict | None):
    """Push an attendance record to Firestore."""
    now = datetime.now(timezone.utc)
    record = {
        "uid":       uid,
        "timestamp": now.isoformat(),
        "date":      now.strftime("%Y-%m-%d"),
        "time":      now.strftime("%H:%M:%S"),
        "status":    "present",
        "valid":     student is not None,
    }

    if student:
        record["student_id"]   = student.get("id", "")
        record["student_name"] = student.get("name", "Unknown")
        record["class_id"]     = student.get("class_id", "")
        log.info(f"✅ Attendance logged: {student.get('name')} ({uid})")
    else:
        record["student_name"] = "Unknown"
        log.warning(f"⚠️  Unknown UID: {uid} — not in student database")

    db.collection("attendance_logs").add(record)


def main():
    db  = init_firebase()
    ser = init_serial(SERIAL_PORT, BAUD_RATE)
    log.info("Listening for RFID scans... Press Ctrl+C to stop.")

    # Debounce tracker: { uid: last_scan_time }
    last_scan: dict[str, datetime] = {}

    try:
        while True:
            raw = ser.readline()
            if not raw:
                continue

            uid = raw.decode("utf-8", errors="ignore").strip().upper()

            # Skip blank lines and the READY signal
            if not uid or uid == "READY":
                continue

            now = datetime.now(timezone.utc)

            # Debounce check
            if uid in last_scan:
                elapsed = (now - last_scan[uid]).total_seconds()
                if elapsed < DEBOUNCE_SEC:
                    log.debug(f"Debounced {uid} ({elapsed:.0f}s ago)")
                    continue

            last_scan[uid] = now

            # Look up student and push record
            student = lookup_student(db, uid)
            push_attendance(db, uid, student)

    except KeyboardInterrupt:
        log.info("Stopped by user.")
    finally:
        ser.close()
        log.info("Serial port closed.")


if __name__ == "__main__":
    main()
