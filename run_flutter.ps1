# Run the Flutter app using your backend server and device code.
cd "$PSScriptRoot"

flutter run -d T8F6ORPJPN79JFGQ --dart-define=BACKEND_BASE_URL=http://172.20.10.3:5000 --dart-define=DEVICE_ID=MASTER_ROOM
