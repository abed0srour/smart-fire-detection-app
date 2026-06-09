# Run the backend with MQTT bridge enabled
cd "$PSScriptRoot\backend"

# Use your laptop IP for MQTT broker
$env:MQTT_BROKER = "172.20.10.3"
$env:MQTT_PORT = "1883"

npm run dev
