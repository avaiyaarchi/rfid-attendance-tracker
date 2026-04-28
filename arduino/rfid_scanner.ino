#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <RTClib.h>
#include <LiquidCrystal_I2C.h>

// RFID Pins
#define SS_PIN 10
#define RST_PIN 9

MFRC522 mfrc522(SS_PIN, RST_PIN);

int mode = 0;

#define BTN1 2
#define BTN2 3

String getStudent(String uid) {
  if (uid == "52AD5C5C") return "240763107004";
  else if (uid == "F107F005") return "230760107052";
  else return "Unknown";
}

String lastTime = "";
String CurrentTime = "";
String CurrentDay = "";


// RTC
RTC_DS1307 rtc;

// LCD (address 0x27 or 0x3F)
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Store last scanned UID
String lastStudent = "";

void setup() {
  Serial.begin(9600);
  SPI.begin();
  mfrc522.PCD_Init();

  Wire.begin();
  rtc.begin();

  lcd.init();
  lcd.backlight();

  pinMode(BTN1, INPUT_PULLUP);
  pinMode(BTN2, INPUT_PULLUP);

  lcd.setCursor(0, 0);
  lcd.print("Smart Attendance");
  delay(4000);
  lcd.clear();

  // If RTC not set
  if (!rtc.isrunning()) {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }
}

void loop() {
    
  if (digitalRead(BTN1) == LOW) {
  mode++;
  if (mode > 2) mode = 0;
  lcd.clear();
  delay(300); // debounce
  }
  
  // MODE 0 → Scan Card
if (mode == 0) {

  lcd.setCursor(0, 0);
  lcd.print("Scan your card");

  // Check RFID
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;

  // Read UID
  String uid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
  byte b = mfrc522.uid.uidByte[i];
  if (b < 0x10) uid += "0"; 
  uid += String(b, HEX);
}

uid.toUpperCase();
  String student = getStudent(uid);

  Serial.println(uid);

  lcd.clear();

  if (student == "Unknown") {
    lcd.print("Invalid User");
    delay(2000);
    return;
  }

  if (student == lastStudent) {
    lcd.print("Already Marked");
    delay(2000);
    return;
  }

  lastStudent = student;

  // Get Time
  DateTime now = rtc.now();

    String h = String(now.hour());
    String m = String(now.minute());
    String s = String(now.second());
    String d = String(now.day());
    String mon = String(now.month());
    String y = String(now.year() % 100);
    
  
  if (now.hour() < 10) h = "0" + h;
  if (now.minute() < 10) m = "0" + m;
  if (now.second() < 10) s = "0" + s;
  if (now.day() < 10) d = "0" + d;
  if (now.month() < 10) mon = "0" + mon;
  if (now.year() < 10) y = "0" + y;

  lastTime = h + ":" + m + ":" + s;

  // Display Attendance
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(student);

  lcd.setCursor(0, 1);
  lcd.print("time: ");
  lcd.print(lastTime);

  delay(5000);
  lcd.clear();
}

// MODE 1 → Show Last Attendance
else if (mode == 1) {

  lcd.setCursor(0, 0);
  lcd.print("Last Record");

  if (digitalRead(BTN2) == LOW) {
    lcd.clear();
    lcd.print(lastStudent);
    lcd.setCursor(0, 1);
    lcd.print("time: ");
    lcd.print(lastTime);
    delay(3000);
    lcd.clear();
  }
}


// MODE 2 → Show Time
else if (mode == 2) {

  lcd.setCursor(0, 0);
  lcd.print("Current Time");

  if (digitalRead(BTN2) == LOW) {
    DateTime now = rtc.now();

    String h = String(now.hour());
    String m = String(now.minute());
    String s = String(now.second());
    String d = String(now.day());
    String mon = String(now.month());
    String y = String(now.year() % 100);
    
    if (now.hour() < 10) h = "0" + h;
    if (now.minute() < 10) m = "0" + m;
    if (now.second() < 10) s = "0" + s;
    if (now.day() < 10) d = "0" + d;
    if (now.month() < 10) mon = "0" + mon;
    if (now.year() < 10) y = "0" + y;

    CurrentTime = h + ":" + m + ":" + s;
    CurrentDay = d + "/" + mon + "/" + y;

    lcd.clear();
    lcd.print("Time: ");
    lcd.print(CurrentTime);

    lcd.setCursor(0, 1);
    lcd.print("Date: ");
    lcd.print(CurrentDay);
    delay(3000);
    lcd.clear();
  }
}
}