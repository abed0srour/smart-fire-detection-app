#include <WiFi.h>
#include <HTTPClient.h>
#include "DHTesp.h"

const char* ssid = "Wokwi-GUEST";
const char* password = "";

// Use your backend machine IPv4 address or tunnel URL.
const char* serverUrl = "http://192.168.169.242:5000/api/sensors";

// Room 1 - Master Room
const int ROOM1_DHT_PIN = 15;
const int ROOM1_MQ_PIN = 34;
const int ROOM1_FLAME_PIN = 4;

// Room 2 - Bedroom
const int ROOM2_DHT_PIN = 16;
const int ROOM2_MQ_PIN = 35;
const int ROOM2_FLAME_PIN = 18;

// Outputs
const int GREEN_LED_PIN = 2;
const int RED_LED_PIN = 5;
const int BUZZER_PIN = 19;

// Danger thresholds. Keep these aligned with backend/app defaults.
const float TEMP_DANGER = 50.0;
const int SMOKE_DANGER = 3000;
const int BATTERY_LEVEL = 90;

const unsigned long SEND_INTERVAL_MS = 5000;
const unsigned long POST_GAP_MS = 1000;

DHTesp dhtRoom1;
DHTesp dhtRoom2;

struct RoomSensor {
  const char* deviceCode;
  const char* label;
  DHTesp* dht;
  int smokePin;
  int flamePin;
};

RoomSensor rooms[] = {
  { "MASTER_ROOM", "Master Room", &dhtRoom1, ROOM1_MQ_PIN, ROOM1_FLAME_PIN },
  { "BEDROOM_1", "Bedroom", &dhtRoom2, ROOM2_MQ_PIN, ROOM2_FLAME_PIN },
};

const int ROOM_COUNT = sizeof(rooms) / sizeof(rooms[0]);

void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  Serial.print("Connecting WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("WiFi Connected. IP: ");
  Serial.println(WiFi.localIP());
}

bool isDanger(float temperature, int smokeLevel, bool flameDetected) {
  return temperature > TEMP_DANGER ||
         smokeLevel > SMOKE_DANGER ||
         flameDetected;
}

String buildPayload(
  const char* deviceCode,
  float temperature,
  float humidity,
  int smokeLevel,
  bool flameDetected
) {
  String payload = "{";
  payload += "\"deviceCode\":\"" + String(deviceCode) + "\",";
  payload += "\"temperature\":" + String(temperature, 1) + ",";
  payload += "\"humidity\":" + String(humidity, 1) + ",";
  payload += "\"smokeLevel\":" + String(smokeLevel) + ",";
  payload += "\"co2Level\":" + String(smokeLevel) + ",";
  payload += "\"flameDetected\":" + String(flameDetected ? "true" : "false") + ",";
  payload += "\"batteryLevel\":" + String(BATTERY_LEVEL);
  payload += "}";
  return payload;
}

int sendSensorData(const String& jsonData) {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
  }

  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");

  Serial.println("Sending:");
  Serial.println(jsonData);

  int responseCode = http.POST(jsonData);

  Serial.print("HTTP Response: ");
  Serial.println(responseCode);

  if (responseCode > 0) {
    Serial.println(http.getString());
  } else {
    Serial.println(http.errorToString(responseCode));
  }

  http.end();
  return responseCode;
}

bool readAndSendRoom(RoomSensor room) {
  TempAndHumidity dhtData = room.dht->getTempAndHumidity();

  if (isnan(dhtData.temperature) || isnan(dhtData.humidity)) {
    Serial.print("Failed to read DHT22 for ");
    Serial.println(room.label);
    return false;
  }

  int smokeLevel = analogRead(room.smokePin);
  bool flameDetected = digitalRead(room.flamePin) == HIGH;
  bool danger = isDanger(dhtData.temperature, smokeLevel, flameDetected);

  Serial.print("========== ");
  Serial.print(room.label);
  Serial.println(" ==========");
  Serial.print("Device Code: ");
  Serial.println(room.deviceCode);
  Serial.print("Temperature: ");
  Serial.println(dhtData.temperature, 1);
  Serial.print("Humidity: ");
  Serial.println(dhtData.humidity, 1);
  Serial.print("Smoke: ");
  Serial.println(smokeLevel);
  Serial.print("Flame: ");
  Serial.println(flameDetected ? "true" : "false");
  Serial.print("Danger: ");
  Serial.println(danger ? "true" : "false");

  String payload = buildPayload(
    room.deviceCode,
    dhtData.temperature,
    dhtData.humidity,
    smokeLevel,
    flameDetected
  );

  sendSensorData(payload);
  return danger;
}

void setup() {
  Serial.begin(115200);

  dhtRoom1.setup(ROOM1_DHT_PIN, DHTesp::DHT22);
  dhtRoom2.setup(ROOM2_DHT_PIN, DHTesp::DHT22);

  pinMode(ROOM1_MQ_PIN, INPUT);
  pinMode(ROOM2_MQ_PIN, INPUT);
  pinMode(ROOM1_FLAME_PIN, INPUT);
  pinMode(ROOM2_FLAME_PIN, INPUT);

  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW);
  noTone(BUZZER_PIN);

  connectWifi();
}

void loop() {
  bool anyDanger = false;

  for (int i = 0; i < ROOM_COUNT; i++) {
    anyDanger = readAndSendRoom(rooms[i]) || anyDanger;

    if (i < ROOM_COUNT - 1) {
      delay(POST_GAP_MS);
    }
  }

  if (anyDanger) {
    digitalWrite(GREEN_LED_PIN, LOW);
    digitalWrite(RED_LED_PIN, HIGH);
    tone(BUZZER_PIN, 1000);
  } else {
    digitalWrite(GREEN_LED_PIN, HIGH);
    digitalWrite(RED_LED_PIN, LOW);
    noTone(BUZZER_PIN);
  }

  delay(SEND_INTERVAL_MS);
}
