# Smart Fire Detection Wokwi ESP32 Simulator

This Wokwi project matches the two-room circuit used by the Flutter app and Node.js backend. It sends one reading for `MASTER_ROOM` and one reading for `BEDROOM_1` to the backend every cycle.

## Backend

Start the backend from the project root:

```powershell
cd backend
npm run dev
```

The ESP32 posts readings to:

```text
POST http://<backend-host>:5000/api/sensors
```

`POST /api/sensors` is intentionally not protected by Firebase Auth because the ESP32 is not a signed-in mobile app user. The matching devices must exist in MongoDB before readings can be saved. The Flutter app provisions the two default circuit devices after sign-in, or you can create rooms manually with these device codes:

- `MASTER_ROOM`
- `BEDROOM_1`

## Configure the Backend URL

Do not use `localhost` inside Wokwi. Edit `serverUrl` at the top of `sketch.ino`:

```cpp
const char* serverUrl = "http://192.168.169.242:5000/api/sensors";
```

Replace the IP address with the host that is reachable from your Wokwi simulation. If requests do not arrive, confirm that the backend is running and that Windows Firewall allows Node.js/port `5000`.

## Open in Wokwi

Option 1: Wokwi web editor

1. Create a new ESP32 Arduino project in Wokwi.
2. Copy `iot-simulator/sketch.ino` into the `sketch.ino` tab.
3. Copy `iot-simulator/diagram.json` into the `diagram.json` tab.
4. Add `DHT sensor library for ESPx` in Library Manager, or copy `iot-simulator/libraries.txt` into the `libraries.txt` tab.
5. Start the simulation and open Serial Monitor.

Option 2: Wokwi VS Code extension

Open the `iot-simulator` folder with the Wokwi extension and start the simulation from there.

## Wiring

The diagram uses:

- Room 1 DHT22 DATA on GPIO `15`
- Room 1 gas sensor analog output on GPIO `34`
- Room 1 flame switch on GPIO `4`
- Room 2 DHT22 DATA on GPIO `16`
- Room 2 gas sensor analog output on GPIO `35`
- Room 2 flame switch on GPIO `18`
- Green safe LED on GPIO `2`
- Red danger LED on GPIO `5`
- Buzzer on GPIO `19`

Each slide switch uses the middle pin as the GPIO input. One side is connected to `GND`, and the other side is connected to `3V3`, so `HIGH` means `flameDetected: true` for that room.

## Test Cases

Safe:

- Set both DHT22 temperatures below or equal to `50 C`.
- Keep both gas sensors below `3000`.
- Put both flame switches in the off/GND position.
- The green LED turns on, the red LED and buzzer stay off, and Serial Monitor prints `Danger: false`.

Danger:

- Set either DHT22 temperature above `50 C`, set either gas sensor above `3000`, or move either flame switch to the on/3V3 position.
- The red LED turns on, the buzzer sounds, and Serial Monitor prints `Danger: true`.
- The HTTP response code should be `201` when the backend accepts the reading.
