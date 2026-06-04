# Smart Fire Detection App

Flutter app for monitoring fire-detection sensor data, alert history, and device settings. The app is wired to the Node.js backend in `backend/` and uses Firebase ID tokens for protected API calls.

## Structure

```text
lib/
  main.dart                  App bootstrap
  src/
    app/                     Theme and navigation shell
    data/
      models/                Sensor and settings data models
      services/              Auth, Node API, and local fallback services
    features/
      auth/                  Firebase sign-up/sign-in screen
      alerts/                Fire alert screen
      dashboard/             Live sensor dashboard
      history/               Alert history screen
      settings/              Device/settings screen
    shared/widgets/          Reusable UI components
```

## Backend

Start the Node API:

```powershell
cd backend
npm start
```

The Flutter app defaults to `http://localhost:5000`. For an Android emulator, run Flutter with:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:5000
```

You can also override the Firebase web API key and device code:

```powershell
flutter run --dart-define=FIREBASE_API_KEY=your_key --dart-define=DEVICE_ID=MASTER_ROOM
```

The checked-in Wokwi simulator sends two device codes: `MASTER_ROOM` and `BEDROOM_1`. After signing in, the app provisions those rooms/devices for the current backend user so `POST /api/sensors` can accept the ESP32 readings.

## Raspberry Pi GrovePi+

The real Raspberry Pi sender is in `raspberry-pi/grovepi_fire_monitor.py`. It posts temperature, humidity, MQ135 gas, flame, light, and status values to the same backend sensor endpoint.

If the backend runs on the Raspberry Pi at `192.168.0.100`, run the app with:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.0.100:5000 --dart-define=DEVICE_ID=MASTER_ROOM
```

On the Pi, run:

```bash
cd raspberry-pi
python3 grovepi_fire_monitor.py
```

If the backend runs on a laptop at `192.168.0.101`, point the Pi sender and app to that laptop:

```bash
BACKEND_SENSOR_URL=http://192.168.0.101:5000/api/sensors python3 grovepi_fire_monitor.py
```

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.0.101:5000 --dart-define=DEVICE_ID=MASTER_ROOM
```

## Development

```powershell
flutter pub get
flutter analyze
flutter test
```
