const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const ThresholdSetting = require("../models/ThresholdSetting");
const Alert = require("../models/Alert");
const User = require("../models/User");
const calculateStatus = require("../utils/calculateStatus");
const sendNotification = require("../utils/sendNotification");
const { emitToUser } = require("../realtime/socket");

const objectIdPattern = /^[0-9a-fA-F]{24}$/;

const deviceIdentifierFilters = (identifier) => {
  const filters = [{ deviceId: identifier }, { deviceCode: identifier }];

  if (objectIdPattern.test(identifier)) {
    filters.push({ _id: identifier });
  }

  return filters;
};

const numberFromPayload = (value) => {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : null;
};

const booleanFromPayload = (value) => {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "string") {
    return value.toLowerCase() === "true";
  }

  return false;
};

const statusFromPayload = (value) => {
  const normalizedValue = value?.toString().trim().toLowerCase();

  if (normalizedValue === "safe" || normalizedValue === "warning") {
    return normalizedValue;
  }

  if (
    normalizedValue === "danger" ||
    normalizedValue === "high" ||
    normalizedValue === "critical" ||
    normalizedValue === "fire"
  ) {
    return "danger";
  }

  return null;
};

const statusRank = {
  safe: 0,
  warning: 1,
  danger: 2,
};

const mostSevereStatus = (...statuses) => {
  return statuses.reduce((selected, status) => {
    if (!status) {
      return selected;
    }

    return statusRank[status] > statusRank[selected] ? status : selected;
  }, "safe");
};

const normalizeRawThreshold = (value, fallback) => {
  const numericValue = Number(value);

  if (!Number.isFinite(numericValue)) {
    return fallback;
  }

  if (numericValue >= 0 && numericValue <= 100) {
    return Math.round((numericValue / 100) * 4095);
  }

  return numericValue;
};

const normalizeThresholds = (thresholds) => {
  const source = thresholds?.toObject ? thresholds.toObject() : thresholds ?? {};
  const normalized = {
    temperatureWarning: 40,
    temperatureDanger: 50,
    smokeWarning: 1800,
    smokeDanger: 3000,
    co2Warning: 1800,
    co2Danger: 3000,
    ...source,
  };

  normalized.smokeWarning = normalizeRawThreshold(
    normalized.smokeWarning,
    1800
  );
  normalized.smokeDanger = normalizeRawThreshold(
    normalized.smokeDanger,
    3000
  );
  normalized.co2Warning = normalizeRawThreshold(
    normalized.co2Warning,
    1800
  );
  normalized.co2Danger = normalizeRawThreshold(
    normalized.co2Danger,
    3000
  );

  if (normalized.co2Warning < normalized.smokeWarning) {
    normalized.co2Warning = normalized.smokeWarning;
  }

  if (normalized.co2Danger < normalized.smokeDanger) {
    normalized.co2Danger = normalized.smokeDanger;
  }

  return normalized;
};

const alertTypeForReading = (sensorData, thresholds) => {
  if (sensorData.flameDetected) {
    return "fire";
  }

  if (sensorData.smokeLevel > thresholds.smokeDanger) {
    return "smoke";
  }

  if (sensorData.co2Level > thresholds.co2Danger) {
    return "co2";
  }

  if (sensorData.temperature > thresholds.temperatureDanger) {
    return "temperature";
  }

  if (sensorData.payloadStatus === "danger" && sensorData.smokeLevel > 0) {
    return "smoke";
  }

  return "light";
};

const alertSnapshotForReading = (reading, batteryLevel) => ({
  readingId: reading._id,
  temperature: reading.temperature,
  smokeLevel: reading.smokeLevel,
  humidity: reading.humidity,
  co2Level: reading.co2Level,
  lightLevel: reading.lightLevel,
  flameLevel: reading.flameLevel,
  flameDetected: reading.flameDetected,
  status: reading.status,
  batteryLevel,
});

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const processSensorPayload = async (payload) => {
  const sensorValues = payload.sensors ?? {};
  const {
    deviceId,
    deviceCode,
    status: payloadStatus,
  } = payload;

  const temperature = sensorValues.temperature ?? payload.temperature;
  const humidity = sensorValues.humidity ?? payload.humidity;
  const smokeLevel = sensorValues.smokeLevel ?? payload.smokeLevel;
  const co2Level = sensorValues.co2Level ?? sensorValues.coLevel ?? payload.co2Level ?? payload.coLevel;
  const lightLevel = sensorValues.lightLevel ?? payload.lightLevel;
  const flameLevel = sensorValues.flameLevel ?? payload.flameLevel;
  const flameDetected = sensorValues.flameDetected ?? payload.flameDetected;
  const batteryLevel = sensorValues.batteryLevel ?? payload.batteryLevel;

  const resolvedDeviceCode = deviceCode || deviceId;
  const resolvedCo2Level = co2Level ?? 0;

  if (!resolvedDeviceCode) {
    const error = new Error("deviceId or deviceCode is required");
    error.statusCode = 400;
    throw error;
  }

  const device = await Device.findOne({
    $or: deviceIdentifierFilters(resolvedDeviceCode),
  });

  if (!device) {
    const error = new Error("Device not found");
    error.statusCode = 404;
    throw error;
  }

  const normalizedTemperature = numberFromPayload(temperature);
  const normalizedSmokeLevel = numberFromPayload(smokeLevel);
  const normalizedHumidity = numberFromPayload(humidity ?? 0);
  const normalizedCo2Level = numberFromPayload(resolvedCo2Level);
  const normalizedLightLevel = numberFromPayload(lightLevel ?? 0);
  const normalizedFlameLevel = numberFromPayload(
    flameLevel ?? (booleanFromPayload(flameDetected) ? 1 : 0)
  );
  const normalizedFlameDetected = booleanFromPayload(flameDetected);
  const normalizedBatteryLevel =
    batteryLevel === undefined ? null : numberFromPayload(batteryLevel);
  const normalizedPayloadStatus = statusFromPayload(payloadStatus);

  if (
    normalizedTemperature === null ||
    normalizedSmokeLevel === null ||
    normalizedCo2Level === null ||
    normalizedLightLevel === null ||
    normalizedFlameLevel === null
  ) {
    const error = new Error(
      "temperature, smokeLevel, co2Level, lightLevel, and flameLevel must be numbers"
    );
    error.statusCode = 400;
    throw error;
  }

  let thresholds = await ThresholdSetting.findOne({ roomId: device.roomId });
  thresholds = normalizeThresholds(thresholds);

  const calculatedStatus = calculateStatus(
    {
      temperature: normalizedTemperature,
      smokeLevel: normalizedSmokeLevel,
      co2Level: normalizedCo2Level,
      flameDetected: normalizedFlameDetected,
    },
    thresholds
  );

  const status = mostSevereStatus(calculatedStatus, normalizedPayloadStatus);

  const reading = await SensorReading.create({
    deviceId: device._id,
    temperature: normalizedTemperature,
    smokeLevel: normalizedSmokeLevel,
    humidity: normalizedHumidity ?? 0,
    co2Level: normalizedCo2Level,
    lightLevel: normalizedLightLevel,
    flameLevel: normalizedFlameLevel,
    flameDetected: normalizedFlameDetected,
    status,
  });

  device.isOnline = true;
  device.lastSeen = new Date();

  if (normalizedBatteryLevel !== null) {
    device.batteryLevel = normalizedBatteryLevel;
  }

  await device.save();

  let alert = null;

  if (status === "danger") {
    const type = alertTypeForReading(
      {
        temperature: normalizedTemperature,
        smokeLevel: normalizedSmokeLevel,
        co2Level: normalizedCo2Level,
        flameDetected: normalizedFlameDetected,
        payloadStatus: normalizedPayloadStatus,
      },
      thresholds
    );
    const snapshot = alertSnapshotForReading(reading, normalizedBatteryLevel);

    await Alert.updateMany(
      {
        userId: device.userId,
        deviceId: device._id,
        isResolved: false,
        message: "Danger detected! Please check the room immediately.",
        type: { $ne: type },
      },
      {
        isResolved: true,
        resolvedAt: new Date(),
      }
    );

    const activeAlert = await Alert.findOne({
      userId: device.userId,
      roomId: device.roomId,
      deviceId: device._id,
      type,
      isResolved: false,
      message: "Danger detected! Please check the room immediately.",
    }).sort({ createdAt: -1 });

    if (activeAlert) {
      await Alert.findByIdAndUpdate(activeAlert._id, {
        ...snapshot,
        severity: "critical",
      });
      alert = await Alert.findById(activeAlert._id);
    } else {
      alert = await Alert.create({
        userId: device.userId,
        roomId: device.roomId,
        deviceId: device._id,
        type,
        message: "Danger detected! Please check the room immediately.",
        severity: "critical",
        ...snapshot,
      });
    }
  } else {
    await Alert.updateMany(
      {
        userId: device.userId,
        deviceId: device._id,
        isResolved: false,
        message: "Danger detected! Please check the room immediately.",
      },
      {
        isResolved: true,
        resolvedAt: new Date(),
      }
    );
  }

  if (alert) {
    const user = await User.findById(device.userId);

    if (user && user.fcmToken) {
      await sendNotification(
        user.fcmToken,
        "Fire Detector Alert",
        alert.message,
        {
          alertId: alert._id.toString(),
          deviceId: device._id.toString(),
          status,
        }
      );
    }
  }

  const populatedReading = await reading.populate("deviceId");
  const populatedAlert = alert
    ? await alert.populate("roomId deviceId readingId")
    : null;

  const realtimePayload = {
    reading: populatedReading,
    deviceId: device._id.toString(),
    deviceCode: device.deviceCode || device.deviceId,
  };

  emitToUser(device.userId, "sensor:reading", realtimePayload);

  if (populatedAlert) {
    emitToUser(device.userId, "alert:created", {
      alert: populatedAlert,
      reading: populatedReading,
      deviceId: device._id.toString(),
      deviceCode: device.deviceCode || device.deviceId,
    });
  }

  return {
    reading: populatedReading,
    device,
    alert: populatedAlert,
  };
};

module.exports = {
  processSensorPayload,
};
