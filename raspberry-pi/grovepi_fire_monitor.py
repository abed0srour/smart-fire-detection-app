#!/usr/bin/env python3
import math
import os
import time

import requests

try:
    import grovepi
except ImportError as error:
    raise SystemExit(
        "Could not import grovepi. Run this script on the Raspberry Pi with "
        "GrovePi installed."
    ) from error


# ================= BACKEND =================

# If the Node backend runs on this Raspberry Pi, keep 127.0.0.1.
# If the backend runs on your laptop, set this to:
# http://YOUR_LAPTOP_IP:5000/api/sensors
BACKEND_SENSOR_URL = os.getenv(
    "BACKEND_SENSOR_URL",
    "http://127.0.0.1:5000/api/sensors",
)

DEVICE_CODE = os.getenv("DEVICE_CODE", "MASTER_ROOM")
SEND_INTERVAL_SECONDS = 5
BATTERY_LEVEL = 100


# ================= GROVEPI PORTS =================

# These match the script you are currently using.
# If your real wiring is different, change only these constants.
DHT_PORT = 3
DHT_TYPE = 0  # 0 = DHT11 / blue sensor, 1 = DHT22 / white sensor

MQ135_PORT = 0  # A0
LIGHT_PORT = 1  # A1
FLAME_PORT = 2  # A2, analog flame output

GREEN_LED_PORT = 5  # D5
ORANGE_LED_PORT = 4  # D4
RED_LED_PORT = 6  # D6

BUZZER_PORT = 2  # D2, active-low buzzer
BUZZER_ON = 0
BUZZER_OFF = 1


# ================= THRESHOLDS =================

TEMP_WARNING = 40.0
TEMP_DANGER = 50.0

# GrovePi analog reads are normally 0-1023.
GAS_WARNING = 300
GAS_DANGER = 500

# Most analog flame sensors read high when there is no flame and low near fire.
FLAME_WARNING = 600
FLAME_DANGER = 400


def configure_ports():
    grovepi.pinMode(MQ135_PORT, "INPUT")
    grovepi.pinMode(LIGHT_PORT, "INPUT")
    grovepi.pinMode(FLAME_PORT, "INPUT")

    for port in (GREEN_LED_PORT, ORANGE_LED_PORT, RED_LED_PORT, BUZZER_PORT):
        grovepi.pinMode(port, "OUTPUT")

    set_outputs("safe")


def safe_read(callable_, fallback):
    try:
        return callable_()
    except (IOError, TypeError, ValueError) as error:
        print(f"Sensor read failed: {error}")
        return fallback


def read_dht():
    temperature, humidity = grovepi.dht(DHT_PORT, DHT_TYPE)

    if temperature is None or humidity is None:
        return 0.0, 0.0

    if math.isnan(temperature) or math.isnan(humidity):
        return 0.0, 0.0

    return float(temperature), float(humidity)


def read_sensors():
    temperature, humidity = safe_read(read_dht, (0.0, 0.0))
    smoke_level = int(safe_read(lambda: grovepi.analogRead(MQ135_PORT), 0))
    light_level = int(safe_read(lambda: grovepi.analogRead(LIGHT_PORT), 0))
    flame_level = int(safe_read(lambda: grovepi.analogRead(FLAME_PORT), 1023))
    flame_detected = flame_level <= FLAME_DANGER

    return {
        "temperature": temperature,
        "humidity": humidity,
        "smokeLevel": smoke_level,
        "co2Level": smoke_level,
        "flameLevel": flame_level,
        "flameDetected": flame_detected,
        "lightLevel": light_level,
    }


def calculate_status(reading):
    if (
        reading["flameDetected"]
        or reading["temperature"] > TEMP_DANGER
        or reading["smokeLevel"] > GAS_DANGER
    ):
        return "danger"

    if (
        reading["temperature"] >= TEMP_WARNING
        or reading["smokeLevel"] >= GAS_WARNING
        or reading["flameLevel"] <= FLAME_WARNING
    ):
        return "warning"

    return "safe"


def write_output(port, value):
    try:
        grovepi.digitalWrite(port, value)
    except IOError as error:
        print(f"Output write failed on port {port}: {error}")


def set_outputs(status):
    if status == "danger":
        write_output(GREEN_LED_PORT, 0)
        write_output(ORANGE_LED_PORT, 0)
        write_output(RED_LED_PORT, 1)
        write_output(BUZZER_PORT, BUZZER_ON)
        return

    if status == "warning":
        write_output(GREEN_LED_PORT, 0)
        write_output(ORANGE_LED_PORT, 1)
        write_output(RED_LED_PORT, 0)
        write_output(BUZZER_PORT, BUZZER_OFF)
        return

    write_output(GREEN_LED_PORT, 1)
    write_output(ORANGE_LED_PORT, 0)
    write_output(RED_LED_PORT, 0)
    write_output(BUZZER_PORT, BUZZER_OFF)


def build_payload(reading, status):
    return {
        "deviceCode": DEVICE_CODE,
        "temperature": round(reading["temperature"], 1),
        "humidity": round(reading["humidity"], 1),
        "smokeLevel": reading["smokeLevel"],
        "co2Level": reading["co2Level"],
        "flameLevel": reading["flameLevel"],
        "flameDetected": reading["flameDetected"],
        "lightLevel": reading["lightLevel"],
        "status": status,
        "batteryLevel": BATTERY_LEVEL,
    }


def send_payload(payload):
    response = requests.post(BACKEND_SENSOR_URL, json=payload, timeout=10)
    print(f"HTTP {response.status_code}: {response.text}")
    response.raise_for_status()


def main():
    print(f"Backend sensor URL: {BACKEND_SENSOR_URL}")
    print(f"Device code: {DEVICE_CODE}")
    configure_ports()

    while True:
        reading = read_sensors()
        status = calculate_status(reading)
        set_outputs(status)
        payload = build_payload(reading, status)

        print("Sending payload:", payload)
        try:
            send_payload(payload)
        except requests.RequestException as error:
            print(f"Backend request failed: {error}")

        time.sleep(SEND_INTERVAL_SECONDS)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        set_outputs("safe")
        print("Stopped.")
