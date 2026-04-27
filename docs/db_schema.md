# Firestore Database Schema

## Collection: `students`

Each document represents one enrolled student.

```
students/{studentId}
{
  name:        string   // "Aarav Shah"
  roll_no:     string   // "CS-2024-042"
  rfid_uid:    string   // "A3F21B09"  ← uppercase hex, from Arduino
  class_id:    string   // Firestore doc ID of their class
  photo_url:   string   // Firebase Storage URL or ""
  created_at:  string   // ISO 8601 timestamp
}
```

---

## Collection: `attendance_logs`

One document per RFID scan event. Created by Python middleware.

```
attendance_logs/{logId}
{
  uid:           string   // RFID UID scanned — "A3F21B09"
  timestamp:     string   // ISO 8601 UTC — "2024-01-15T09:30:00+00:00"
  date:          string   // "2024-01-15"  ← used for daily queries
  time:          string   // "09:30:00"
  status:        string   // "present" (future: "late", "excused")
  valid:         bool     // true if UID matched a student record
  student_id:    string   // Firestore doc ID from students/ (if valid)
  student_name:  string   // Denormalized name for fast display
  class_id:      string   // From student record (if valid)
  manual:        bool     // true if entered via app fallback (optional)
}
```

**Indexes required** (create in Firebase Console → Firestore → Indexes):

| Collection      | Fields                              | Query scope |
|-----------------|-------------------------------------|-------------|
| attendance_logs | date ASC, timestamp DESC            | Collection  |
| attendance_logs | student_id ASC, timestamp DESC      | Collection  |
| attendance_logs | class_id ASC, date ASC              | Collection  |

---

## Collection: `classes`

```
classes/{classId}
{
  name:        string     // "Class 10-A"
  teacher:     string     // Teacher's name
  student_ids: string[]   // Array of student doc IDs
  created_at:  string     // ISO 8601
}
```

---

## Collection: `users`

Stores role information for authenticated Firebase users.

```
users/{firebaseUid}
{
  email:  string   // matches Firebase Auth email
  role:   string   // "admin" | "teacher"
  name:   string   // display name
}
```

---

## Common Queries

### All attendance for today
```javascript
db.collection('attendance_logs')
  .where('date', '==', '2024-01-15')
  .orderBy('timestamp', 'desc')
```

### Student attendance history
```javascript
db.collection('attendance_logs')
  .where('student_id', '==', studentId)
  .orderBy('timestamp', 'desc')
  .limit(30)
```

### Class attendance on a date
```javascript
db.collection('attendance_logs')
  .where('class_id', '==', classId)
  .where('date', '==', date)
```

### Lookup student by RFID UID (used by middleware)
```python
db.collection('students').where('rfid_uid', '==', uid).limit(1).get()
```
