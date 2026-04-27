# MFRC522 RFID Module — Wiring Guide

## Pin Connections

### Arduino Uno / Nano

| MFRC522 | Arduino Uno | Arduino Nano |
|---------|-------------|--------------|
| SDA     | Pin 10      | Pin 10       |
| SCK     | Pin 13      | Pin 13       |
| MOSI    | Pin 11      | Pin 11       |
| MISO    | Pin 12      | Pin 12       |
| IRQ     | Not used    | Not used     |
| GND     | GND         | GND          |
| RST     | Pin 9       | Pin 9        |
| 3.3V    | 3.3V ⚠️     | 3.3V ⚠️      |

### Arduino Mega

| MFRC522 | Arduino Mega |
|---------|--------------|
| SDA     | Pin 53       |
| SCK     | Pin 52       |
| MOSI    | Pin 51       |
| MISO    | Pin 50       |
| GND     | GND          |
| RST     | Pin 5        |
| 3.3V    | 3.3V ⚠️      |

> ⚠️ **Critical:** MFRC522 operates at 3.3V. Connecting to 5V will damage the module.

---

## LED Feedback (Optional)

```
Arduino Pin 7 ──[220Ω resistor]──[LED anode]──[LED cathode]── GND
```

The LED blinks briefly on each successful card scan.

---

## Schematic (Text)

```
                    ┌──────────────────┐
                    │   Arduino Uno    │
                    │                  │
           3.3V ────┤ 3.3V             │
           GND  ────┤ GND              │
  MFRC522  SDA  ────┤ Pin 10 (SS)      │
           SCK  ────┤ Pin 13 (SCK)     │
           MOSI ────┤ Pin 11 (MOSI)    │
           MISO ────┤ Pin 12 (MISO)    │
           RST  ────┤ Pin 9            │
                    │                  │
  LED+ ─[220Ω]─────┤ Pin 7            │
  LED- ────────────┤ GND              │
                    │                  │
                    │ USB ─────────────┼──── PC (Python reads Serial)
                    └──────────────────┘
```

---

## Installing the MFRC522 Library

1. Open Arduino IDE
2. Go to **Sketch → Include Library → Manage Libraries**
3. Search for `MFRC522`
4. Install **MFRC522 by GithubCommunity** (version 1.4.x or later)

---

## Testing the RFID Reader

Before running the full attendance sketch, test with the library example:

1. Open **File → Examples → MFRC522 → DumpInfo**
2. Upload to Arduino
3. Open Serial Monitor at 9600 baud
4. Hold an RFID card near the reader
5. You should see the card's UID and other data printed

If nothing appears:
- Double-check SDA, SCK, MOSI, MISO wiring
- Confirm you're using 3.3V not 5V
- Try increasing the gain: add `rfid.PCD_SetAntennaGain(rfid.RxGain_max)` in `setup()`

---

## Supported Card Types

The MFRC522 works with:
- **Mifare Classic 1K** (most common, white key fobs)
- **Mifare Classic 4K**
- **Mifare Ultralight**
- **Mifare Mini**
- **ISO/IEC 14443-A** compatible cards (13.56 MHz)

It does NOT work with:
- 125 kHz EM4100 cards (different frequency)
- Credit cards (different protocol)
