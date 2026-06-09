#!/bin/bash
# Run this on the Raspberry Pi in the directory that contains main.py.

cd "$HOME"

export MQTT_BROKER=172.20.10.3
export MQTT_PORT=1883
export DEVICE_CODE=MASTER_ROOM

python3 main.py
