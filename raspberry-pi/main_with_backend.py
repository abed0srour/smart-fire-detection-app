#!/usr/bin/env python3
import time
import math
import os
import requests
import grovepi

# =======================
# BACKEND CONFIGURATION
# =======================

BACKEND_SENSOR_URL = os.getenv(
    "BACKEND_SENSOR_URL",
    "http://127.0.0.1:5000/api/sensors",
)

DEVICE_CODE = os.getenv("DEVICE_CODE", "MASTER_ROOM")
SEND_INTERVAL_SECONDS = 2
BATTERY_LEVEL = 100

# =======================
# PORTS
# =======================

DHT_PORT = 3
DHT_TYPE = 0  # DHT11

MQ_PORT = 0
FLAME_PORT = 2
LIGHT_PORT = 1

GREEN_LED = 5
ORANGE_LED = 4
RED_LED = 6
BUZZER = 2

# =======================
# THRESHOLDS
# =======================

GAS_WARNING = 300
GAS_DANGER = 500

TEMP_WARNING = 40
TEMP_DANGER = 50

FLAME_WARNING = 600
FLAME_DANGER = 400

# =======================
# SETUP
# =======================

grovepi.pinMode(GREEN_LED, "OUTPUT")
grovepi.pinMode(ORANGE_LED, "OUTPUT")
grovepi.pinMode(RED_LED, "OUTPUT")
grovepi.pinMode(BUZZER, "OUTPUT")


# =======================
# OUTPUT MODES
# =======================

def all_outputs_off():
    grovepi.digitalWrite(GREEN_LED, 0)
    grovepi.digitalWrite(ORANGE_LED, 0)
    grovepi.digitalWrite(RED_LED, 0)
    grovepi.digitalWrite(BUZZER, 0)


def normal_mode():
    all_outputs_off()
    grovepi.digitalWrite(GREEN_LED, 1)


def warning_mode():
    all_outputs_off()
    grovepi.digitalWrite(ORANGE_LED, 1)


def fire_mode():
    all_outputs_off()

    grovepi.digitalWrite(RED_LED, 1)
    time.sleep(0.3)
    grovepi.digitalWrite(RED_LED, 0)
    time.sleep(0.3)


def danger_mode():
    all_outputs_off()

    grovepi.digitalWrite(RED_LED, 1)
    grovepi.digitalWrite(BUZZER, 1)


# =======================
# SENSOR READING
# =======================

def read_temp_humidity():
    try:
        temp, hum = grovepi.dht(DHT_PORT, DHT_TYPE)

        if (
            temp == -1
            or hum == -1
            or math.isnan(temp)
            or math.isnan(hum)
        ):
            return None, None

        return temp, hum

    except Exception as e:
        print("DHT Error:", e)
        return None, None


def read_analog(port, name):
    try:
        value = grovepi.analogRead(port)

        if value < 0:
            print(name, "read error")
            return None

        return value

    except Exception as e:
        print(name, "Error:", e)
        return None


# =======================
# STATUS LOGIC
# =======================

def get_status(temp, gas, flame):

    reasons = []

    fire_detected = False
    gas_warning = False
    gas_danger = False

    temp_warning = False
    temp_danger = False

    # GAS
    if gas is not None:
        if gas >= GAS_DANGER:
            gas_danger = True
            reasons.append("Critical gas level")

        elif gas >= GAS_WARNING:
            gas_warning = True
            reasons.append("Gas level rising")

    # TEMPERATURE
    if temp is not None:
        if temp >= TEMP_DANGER:
            temp_danger = True
            reasons.append("Critical temperature")

        elif temp >= TEMP_WARNING:
            temp_warning = True
            reasons.append("Temperature warning")

    # FLAME
    if flame is not None:
        if flame <= FLAME_DANGER:
            fire_detected = True
            reasons.append("Flame detected")

        elif flame <= FLAME_WARNING:
            reasons.append("Possible flame nearby")

    # DANGER
    if fire_detected and (gas_danger or temp_danger):
        return "danger", reasons

    # FIRE
    if fire_detected:
        return "fire", reasons

    # WARNING
    if (
        gas_warning
        or temp_warning
        or gas_danger
        or temp_danger
        or (flame is not None and flame <= FLAME_WARNING)
    ):
        return "warning", reasons

    # NORMAL
    return "normal", ["All sensors normal"]


# =======================
# BACKEND INTEGRATION
# =======================

def build_payload(temp, hum, gas, flame, light, status):
    """Build JSON payload for the backend sensor endpoint."""
    flame_detected = flame is not None and flame <= FLAME_DANGER
    
    return {
        "deviceCode": DEVICE_CODE,
        "temperature": round(temp, 1) if temp is not None else 0,
        "humidity": round(hum, 1) if hum is not None else 0,
        "smokeLevel": gas if gas is not None else 0,
        "co2Level": gas if gas is not None else 0,
        "flameLevel": flame if flame is not None else 1023,
        "flameDetected": flame_detected,
        "lightLevel": light if light is not None else 0,
        "status": "danger" if status == "fire" or status == "danger" else "safe" if status == "normal" else "warning",
        "batteryLevel": BATTERY_LEVEL,
    }


def send_to_backend(payload):
    """Send sensor payload to the backend."""
    try:
        response = requests.post(BACKEND_SENSOR_URL, json=payload, timeout=5)
        
        if response.status_code == 200:
            print(f"✓ Backend POST success (HTTP {response.status_code})")
        else:
            print(f"✗ Backend POST failed (HTTP {response.status_code}): {response.text}")
        
        return response.status_code == 200
        
    except requests.exceptions.Timeout:
        print("✗ Backend request TIMEOUT (check network/URL)")
        return False
    except requests.exceptions.ConnectionError:
        print("✗ Backend connection ERROR (check URL and network)")
        return False
    except Exception as e:
        print(f"✗ Backend request error: {e}")
        return False


# =======================
# MAIN PROGRAM
# =======================

print("====================================")
print(" FIRE DETECTION SYSTEM STARTED")
print("====================================")
print(f"Backend URL: {BACKEND_SENSOR_URL}")
print(f"Device Code: {DEVICE_CODE}")
print("====================================\n")

try:

    while True:

        temp, hum = read_temp_humidity()

        gas = read_analog(MQ_PORT, "MQ135")
        flame = read_analog(FLAME_PORT, "Flame")
        light = read_analog(LIGHT_PORT, "Light")

        status, reasons = get_status(temp, gas, flame)

        print("\n==============================")
        print("Temperature :", temp, "C")
        print("Humidity    :", hum, "%")
        print("Gas MQ135   :", gas)
        print("Flame       :", flame)
        print("Light       :", light)
        print("STATUS      :", status.upper())

        for reason in reasons:
            print("-", reason)

        # Control LEDs locally
        if status == "danger":
            danger_mode()

        elif status == "fire":
            fire_mode()

        elif status == "warning":
            warning_mode()

        else:
            normal_mode()

        # Send to backend
        payload = build_payload(temp, hum, gas, flame, light, status)
        print("\nSending to backend:", payload)
        send_to_backend(payload)

        time.sleep(SEND_INTERVAL_SECONDS)

except KeyboardInterrupt:

    print("\nStopping system...")

    all_outputs_off()
