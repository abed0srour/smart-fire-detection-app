# Raspberry Pi GrovePi+ Fire Monitor

This script reads the GrovePi+ sensors and posts readings to the existing Node backend at `POST /api/sensors`.

## Default Ports

Change these constants in `grovepi_fire_monitor.py` if your wiring is different:

- DHT temperature/humidity: `D3`
- MQ135 gas sensor: `A0`
- Light sensor: `A1`
- Flame sensor analog output: `A2`
- Green LED: `D5`
- Orange LED: `D4`
- Red LED: `D6`
- Active-low buzzer: `D2`

If your flame sensor is physically connected to `A1` and your light sensor to
`A2`, swap `LIGHT_PORT` and `FLAME_PORT` in `grovepi_fire_monitor.py`.

The active-low buzzer uses:

- `0` = ON
- `1` = OFF

## Backend URL

If the Node backend runs on the Raspberry Pi:

```bash
export BACKEND_SENSOR_URL=http://127.0.0.1:5000/api/sensors
```

If the Node backend runs on your laptop, use the laptop IP instead:

```bash
export BACKEND_SENSOR_URL=http://YOUR_LAPTOP_IP:5000/api/sensors
```

`192.168.0.100` is the Raspberry Pi IP, so do not use it as
`BACKEND_SENSOR_URL` unless the Node backend is running on the Pi.

Your Raspberry Pi IP `192.168.0.100` is useful for connecting to the Pi from your phone/laptop. If the backend runs on the Pi, run the Flutter app with:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.0.100:5000 --dart-define=DEVICE_ID=MASTER_ROOM
```

## Run

Install requests if needed:

```bash
pip3 install requests
```

Run the monitor:

```bash
cd raspberry-pi
python3 grovepi_fire_monitor.py
```

To use another device code:

```bash
DEVICE_CODE=BEDROOM_1 python3 grovepi_fire_monitor.py
```

The backend must already have a device whose `deviceCode` is `MASTER_ROOM` or `BEDROOM_1`. Sign in to the Flutter app once; it provisions those default devices for the current user.
