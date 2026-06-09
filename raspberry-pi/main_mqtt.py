#!/usr/bin/env python3
"""
MQTT-based Fire Detection System for Raspberry Pi
Publishes sensor readings via MQTT and receives commands via MQTT
"""

import time
import math
import os
import json
import paho.mqtt.client as mqtt
import grovepi
from threading import Lock

# =======================
# MQTT BROKER CONFIGURATION
# =======================

MQTT_BROKER = os.getenv("MQTT_BROKER", "172.20.10.3")  # Laptop/Pi/Server IP
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME", "")
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", "")

DEVICE_CODE = os.getenv("DEVICE_CODE", "MASTER_ROOM")

# MQTT Topics
TOPIC_PUBLISH_SENSORS = f"fire-detection/{DEVICE_CODE}/sensors"      # Pi publishes sensor data here
TOPIC_SUBSCRIBE_COMMANDS = f"fire-detection/{DEVICE_CODE}/commands"  # Pi listens for commands here
TOPIC_SUBSCRIBE_CONFIG = f"fire-detection/{DEVICE_CODE}/config"      # Pi listens for config updates

PUBLISH_INTERVAL_SECONDS = 2
BATTERY_LEVEL = 100

# =======================
# GROVEPI PORTS
# =======================

DHT_PORT = 3
DHT_TYPE = 0  # DHT11

MQ_PORT = 0
FLAME_PORT = 2
LIGHT_PORT = 1

GREEN_LED = 5
ORANGE_LED = 4
RED_LED = 6
BUZZER = 7

# =======================
# THRESHOLDS (can be updated via MQTT config)
# =======================

GAS_WARNING = 300
GAS_DANGER = 500

TEMP_WARNING = 40
TEMP_DANGER = 50

FLAME_WARNING = 600
FLAME_DANGER = 400

# =======================
# GLOBAL STATE
# =======================

state_lock = Lock()
mqtt_connected = False
last_publish_time = 0

# =======================
# SETUP
# =======================

def setup_ports():
    """Initialize GrovePi ports"""
    try:
        grovepi.pinMode(GREEN_LED, "OUTPUT")
        grovepi.pinMode(ORANGE_LED, "OUTPUT")
        grovepi.pinMode(RED_LED, "OUTPUT")
        grovepi.pinMode(BUZZER, "OUTPUT")
        all_outputs_off()
        print("[SETUP] GrovePi ports initialized")
    except Exception as e:
        print(f"[SETUP ERROR] Failed to initialize ports: {e}")


# =======================
# OUTPUT CONTROL
# =======================

def all_outputs_off():
    """Turn off all LEDs and buzzer"""
    try:
        grovepi.digitalWrite(GREEN_LED, 0)
        grovepi.digitalWrite(ORANGE_LED, 0)
        grovepi.digitalWrite(RED_LED, 0)
        grovepi.digitalWrite(BUZZER, 0)
    except Exception as e:
        print(f"[OUTPUT ERROR] {e}")


def set_status_lights(status):
    """Set LED state based on status"""
    try:
        if status == "danger":
            all_outputs_off()
            grovepi.digitalWrite(RED_LED, 1)
            grovepi.digitalWrite(BUZZER, 1)
            print("[LIGHTS] Danger mode: RED LED + BUZZER ON")
            
        elif status == "warning":
            all_outputs_off()
            grovepi.digitalWrite(ORANGE_LED, 1)
            print("[LIGHTS] Warning mode: ORANGE LED ON")
            
        elif status == "fire":
            all_outputs_off()
            for _ in range(3):
                grovepi.digitalWrite(RED_LED, 1)
                time.sleep(0.3)
                grovepi.digitalWrite(RED_LED, 0)
                time.sleep(0.3)
            grovepi.digitalWrite(BUZZER, 1)
            print("[LIGHTS] Fire mode: RED LED FLASHING + BUZZER ON")
            
        else:  # safe/normal
            all_outputs_off()
            grovepi.digitalWrite(GREEN_LED, 1)
            print("[LIGHTS] Safe mode: GREEN LED ON")
            
    except Exception as e:
        print(f"[OUTPUT ERROR] Failed to set lights: {e}")


def buzzer_on():
    """Turn buzzer on"""
    try:
        grovepi.digitalWrite(BUZZER, 1)
    except Exception as e:
        print(f"[OUTPUT ERROR] Buzzer on failed: {e}")


def buzzer_off():
    """Turn buzzer off"""
    try:
        grovepi.digitalWrite(BUZZER, 0)
    except Exception as e:
        print(f"[OUTPUT ERROR] Buzzer off failed: {e}")


# =======================
# SENSOR READING
# =======================

def read_temp_humidity():
    """Read DHT11 temperature and humidity"""
    try:
        temp, hum = grovepi.dht(DHT_PORT, DHT_TYPE)
        
        if temp is None or hum is None or math.isnan(temp) or math.isnan(hum):
            return None, None
        
        return float(temp), float(hum)
        
    except Exception as e:
        print(f"[SENSOR ERROR] DHT read failed: {e}")
        return None, None


def read_analog(port, name):
    """Read analog sensor value"""
    try:
        value = grovepi.analogRead(port)
        
        if value < 0:
            print(f"[SENSOR ERROR] {name} returned negative value: {value}")
            return None
        
        return int(value)
        
    except Exception as e:
        print(f"[SENSOR ERROR] {name} read failed: {e}")
        return None


def read_all_sensors():
    """Read all sensors and return sensor data dict"""
    temp, hum = read_temp_humidity()
    gas = read_analog(MQ_PORT, "MQ135")
    flame = read_analog(FLAME_PORT, "Flame")
    light = read_analog(LIGHT_PORT, "Light")
    
    flame_detected = (flame is not None) and (flame <= FLAME_DANGER)
    
    return {
        "temperature": round(temp, 1) if temp is not None else 0.0,
        "humidity": round(hum, 1) if hum is not None else 0.0,
        "smokeLevel": gas if gas is not None else 0,
        "co2Level": gas if gas is not None else 0,
        "flameLevel": flame if flame is not None else 1023,
        "flameDetected": flame_detected,
        "lightLevel": light if light is not None else 0,
        "batteryLevel": BATTERY_LEVEL,
        "timestamp": int(time.time()),
    }


# =======================
# STATUS CALCULATION
# =======================

def calculate_status(sensors):
    """Determine system status based on sensor readings"""
    temp = sensors["temperature"]
    gas = sensors["smokeLevel"]
    flame = sensors["flameDetected"]
    
    reasons = []
    
    # Check for fire
    if flame:
        reasons.append("Flame detected")
        if gas >= GAS_DANGER or temp >= TEMP_DANGER:
            return "danger", reasons
        return "fire", reasons
    
    # Check for danger
    if temp >= TEMP_DANGER or gas >= GAS_DANGER:
        reasons.append("Critical temperature" if temp >= TEMP_DANGER else "")
        reasons.append("Critical gas level" if gas >= GAS_DANGER else "")
        return "danger", [r for r in reasons if r]
    
    # Check for warning
    if temp >= TEMP_WARNING or gas >= GAS_WARNING or sensors["flameLevel"] <= FLAME_WARNING:
        if temp >= TEMP_WARNING:
            reasons.append("Temperature warning")
        if gas >= GAS_WARNING:
            reasons.append("Gas level rising")
        if sensors["flameLevel"] <= FLAME_WARNING:
            reasons.append("Possible flame nearby")
        return "warning", reasons
    
    # Safe
    return "safe", ["All sensors normal"]


# =======================
# MQTT CALLBACKS
# =======================

def on_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    global mqtt_connected
    
    if rc == 0:
        mqtt_connected = True
        print(f"[MQTT] Connected to broker {MQTT_BROKER}:{MQTT_PORT}")
        
        # Subscribe to command and config topics
        client.subscribe(TOPIC_SUBSCRIBE_COMMANDS)
        client.subscribe(TOPIC_SUBSCRIBE_CONFIG)
        print(f"[MQTT] Subscribed to {TOPIC_SUBSCRIBE_COMMANDS} and {TOPIC_SUBSCRIBE_CONFIG}")
        
    else:
        mqtt_connected = False
        print(f"[MQTT ERROR] Connection failed with code {rc}")


def on_disconnect(client, userdata, rc):
    """MQTT disconnection callback"""
    global mqtt_connected
    mqtt_connected = False
    
    if rc != 0:
        print(f"[MQTT] Disconnected unexpectedly with code {rc}")
    else:
        print("[MQTT] Disconnected gracefully")


def on_message(client, userdata, msg):
    """Handle incoming MQTT messages"""
    topic = msg.topic
    payload = msg.payload.decode('utf-8')
    
    print(f"\n[MQTT RECEIVED] Topic: {topic}")
    print(f"[MQTT RECEIVED] Payload: {payload}")
    
    try:
        if "commands" in topic:
            handle_command(payload)
        elif "config" in topic:
            handle_config(payload)
    except Exception as e:
        print(f"[MQTT ERROR] Failed to process message: {e}")


def handle_command(payload):
    """Process commands received from MQTT"""
    try:
        command = json.loads(payload)
        action = command.get("action", "").lower()
        
        print(f"[COMMAND] Action: {action}")
        
        if action == "buzzer_on":
            buzzer_on()
            print("[COMMAND] Buzzer turned ON")
            
        elif action == "buzzer_off":
            buzzer_off()
            print("[COMMAND] Buzzer turned OFF")
            
        elif action == "all_off":
            all_outputs_off()
            print("[COMMAND] All outputs turned OFF")
            
        elif action == "set_lights":
            status = command.get("status", "safe")
            set_status_lights(status)
            print(f"[COMMAND] Lights set to {status}")
            
    except json.JSONDecodeError:
        print("[COMMAND ERROR] Invalid JSON in command")
    except Exception as e:
        print(f"[COMMAND ERROR] {e}")


def handle_config(payload):
    """Process configuration updates from MQTT"""
    global GAS_WARNING, GAS_DANGER, TEMP_WARNING, TEMP_DANGER, FLAME_WARNING, FLAME_DANGER
    
    try:
        config = json.loads(payload)
        
        if "gas_warning" in config:
            GAS_WARNING = config["gas_warning"]
        if "gas_danger" in config:
            GAS_DANGER = config["gas_danger"]
        if "temp_warning" in config:
            TEMP_WARNING = config["temp_warning"]
        if "temp_danger" in config:
            TEMP_DANGER = config["temp_danger"]
        if "flame_warning" in config:
            FLAME_WARNING = config["flame_warning"]
        if "flame_danger" in config:
            FLAME_DANGER = config["flame_danger"]
        
        print(f"[CONFIG] Updated thresholds: {config}")
        
    except json.JSONDecodeError:
        print("[CONFIG ERROR] Invalid JSON in config")
    except Exception as e:
        print(f"[CONFIG ERROR] {e}")


def on_publish(client, userdata, mid):
    """MQTT publish callback"""
    print(f"[MQTT] Message published (mid={mid})")


def on_subscribe(client, userdata, mid, granted_qos):
    """MQTT subscribe callback"""
    print(f"[MQTT] Subscription acknowledged (mid={mid})")


# =======================
# MQTT CLIENT SETUP
# =======================

def setup_mqtt_client():
    """Create and configure MQTT client"""
    client = mqtt.Client(client_id=f"fire-detection-{DEVICE_CODE}")
    
    # Set credentials if provided
    if MQTT_USERNAME and MQTT_PASSWORD:
        client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        print(f"[MQTT] Using credentials: {MQTT_USERNAME}:***")
    
    # Set callbacks
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.on_publish = on_publish
    client.on_subscribe = on_subscribe
    
    return client


# =======================
# MAIN LOOP
# =======================

def main():
    """Main program loop"""
    global mqtt_connected, last_publish_time
    
    print("=" * 50)
    print(" MQTT FIRE DETECTION SYSTEM STARTED")
    print("=" * 50)
    print(f"Broker: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"Device Code: {DEVICE_CODE}")
    print(f"Sensor topic: {TOPIC_PUBLISH_SENSORS}")
    print(f"Command topic: {TOPIC_SUBSCRIBE_COMMANDS}")
    print(f"Config topic: {TOPIC_SUBSCRIBE_CONFIG}")
    print("=" * 50 + "\n")
    
    setup_ports()
    
    # Setup MQTT client
    client = setup_mqtt_client()
    
    try:
        # Connect to broker
        print("[MQTT] Connecting to broker...")
        client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
        client.loop_start()  # Start network loop in background thread
        
        # Give connection time to establish
        time.sleep(2)
        
        # Main sensor reading loop
        while True:
            # Read all sensors
            sensors = read_all_sensors()
            status, reasons = calculate_status(sensors)
            
            # Print sensor data
            print("\n" + "=" * 50)
            print(f"Temperature: {sensors['temperature']}°C")
            print(f"Humidity: {sensors['humidity']}%")
            print(f"Smoke (MQ135): {sensors['smokeLevel']}")
            print(f"Flame Level: {sensors['flameLevel']}")
            print(f"Flame Detected: {sensors['flameDetected']}")
            print(f"Light Level: {sensors['lightLevel']}")
            print(f"Status: {status.upper()}")
            for reason in reasons:
                print(f"  → {reason}")
            print("=" * 50)
            
            # Update local lights
            set_status_lights(status)
            
            # Publish to MQTT if connected
            if mqtt_connected:
                payload = {
                    "deviceCode": DEVICE_CODE,
                    **sensors,
                    "status": status,
                    "reasons": reasons,
                }
                
                try:
                    result = client.publish(
                        TOPIC_PUBLISH_SENSORS,
                        json.dumps(payload),
                        qos=1,
                        retain=False
                    )
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        print(f"[MQTT] Published sensor data to {TOPIC_PUBLISH_SENSORS}")
                    else:
                        print(f"[MQTT ERROR] Publish failed with code {result.rc}")
                        
                except Exception as e:
                    print(f"[MQTT ERROR] Failed to publish: {e}")
            else:
                print("[MQTT WARNING] Not connected to broker - sensor data not sent")
            
            time.sleep(PUBLISH_INTERVAL_SECONDS)
    
    except KeyboardInterrupt:
        print("\n[SHUTDOWN] Stopping system...")
        
    except Exception as e:
        print(f"\n[FATAL ERROR] {e}")
        
    finally:
        # Cleanup
        all_outputs_off()
        client.loop_stop()
        client.disconnect()
        print("[SHUTDOWN] MQTT disconnected and ports cleaned up")


if __name__ == "__main__":
    main()
