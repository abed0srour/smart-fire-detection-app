const mqtt = require("mqtt");
const { processSensorPayload } = require("./services/sensorProcessor");

const MQTT_BROKER = process.env.MQTT_BROKER || "";
const MQTT_PORT = process.env.MQTT_PORT || "1883";
const MQTT_USERNAME = process.env.MQTT_USERNAME || "";
const MQTT_PASSWORD = process.env.MQTT_PASSWORD || "";
const MQTT_CLIENT_ID = process.env.MQTT_CLIENT_ID || `backend-mqtt-bridge-${Date.now()}`;
const MQTT_TOPIC = "fire-detection/+/sensors";

const buildBrokerUrl = () => {
  if (!MQTT_BROKER) {
    return null;
  }

  if (MQTT_BROKER.startsWith("mqtt://") || MQTT_BROKER.startsWith("ws://") || MQTT_BROKER.startsWith("wss://")) {
    return MQTT_BROKER;
  }

  return `mqtt://${MQTT_BROKER}:${MQTT_PORT}`;
};

const initializeMqttBridge = () => {
  const brokerUrl = buildBrokerUrl();

  if (!brokerUrl) {
    console.log("[MQTT BRIDGE] MQTT_BROKER not configured. MQTT bridge is disabled.");
    return;
  }

  const options = {
    clientId: MQTT_CLIENT_ID,
    keepalive: 60,
    reconnectPeriod: 5000,
  };

  if (MQTT_USERNAME && MQTT_PASSWORD) {
    options.username = MQTT_USERNAME;
    options.password = MQTT_PASSWORD;
  }

  const client = mqtt.connect(brokerUrl, options);

  client.on("connect", () => {
    console.log(`[MQTT BRIDGE] Connected to broker ${brokerUrl}`);
    client.subscribe(MQTT_TOPIC, { qos: 1 }, (err, granted) => {
      if (err) {
        console.error("[MQTT BRIDGE] Subscribe error:", err);
        return;
      }
      console.log(`[MQTT BRIDGE] Subscribed to ${MQTT_TOPIC}`, granted);
    });
  });

  client.on("reconnect", () => {
    console.log("[MQTT BRIDGE] Reconnecting to MQTT broker...");
  });

  client.on("error", (error) => {
    console.error("[MQTT BRIDGE] MQTT client error:", error.message || error);
  });

  client.on("message", async (topic, message) => {
    try {
      const payloadString = message.toString("utf-8");
      console.log(`[MQTT BRIDGE] Message received on ${topic}: ${payloadString}`);

      const payload = JSON.parse(payloadString);
      const result = await processSensorPayload(payload);

      console.log(
        `[MQTT BRIDGE] Stored reading ${result.reading._id} for device ${result.device.deviceCode || result.device.deviceId}`
      );
    } catch (error) {
      console.error("[MQTT BRIDGE] Failed to process MQTT payload:", error.message || error, error);
    }
  });

  client.on("close", () => {
    console.log("[MQTT BRIDGE] MQTT connection closed.");
  });
};

module.exports = {
  initializeMqttBridge,
};
