const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const ThresholdSetting = require("../models/ThresholdSetting");
const Alert = require("../models/Alert");
const User = require("../models/User");

const calculateStatus = require("../utils/calculateStatus");
const sendNotification = require("../utils/sendNotification");
const { emitToUser } = require("../realtime/socket");

const logSensor = (message, details = {}) => {
  console.log(`[sensorController] ${message}`, details);
};

const objectIdPattern = /^[0-9a-fA-F]{24}$/;

const DEFAULT_THRESHOLDS = {
  temperatureWarning: 40,
  temperatureDanger: 50,
  smokeWarning: 1800,
  smokeDanger: 3000,
  co2Warning: 1800,
  co2Danger: 3000,
};

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

const statusRank = {
  safe: 0,
  warning: 1,
  danger: 2,
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
    ...DEFAULT_THRESHOLDS,
    ...source,
  };

  normalized.smokeWarning = normalizeRawThreshold(
    normalized.smokeWarning,
    DEFAULT_THRESHOLDS.smokeWarning
  );
  normalized.smokeDanger = normalizeRawThreshold(
    normalized.smokeDanger,
    DEFAULT_THRESHOLDS.smokeDanger
  );
  normalized.co2Warning = normalizeRawThreshold(
    normalized.co2Warning,
    DEFAULT_THRESHOLDS.co2Warning
  );
  normalized.co2Danger = normalizeRawThreshold(
    normalized.co2Danger,
    DEFAULT_THRESHOLDS.co2Danger
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

const alertMessage = "Danger detected! Please check the room immediately.";

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

const findUserDevice = async (firebaseUid, identifier) => {
  const user = await getCurrentUser(firebaseUid);

  if (!user) {
    return null;
  }

  return await Device.findOne({
    userId: user._id,
    $or: deviceIdentifierFilters(identifier),
  });
};

const addSensorReading = async (req, res) => {
  try {
    logSensor("received payload", req.body);

    const {
      deviceId,
      deviceCode,
      temperature,
      smokeLevel,
      humidity,
      co2Level,
      coLevel,
      lightLevel,
      flameLevel,
      flameDetected,
      batteryLevel,
      status: payloadStatus,
    } = req.body;

    const resolvedDeviceCode = deviceCode || deviceId;
    const resolvedCo2Level = co2Level ?? coLevel ?? 0;

    if (!resolvedDeviceCode) {
      logSensor("response status", {
        status: 400,
        message: "deviceId or deviceCode is required",
      });
      return res.status(400).json({
        success: false,
        message: "deviceId or deviceCode is required",
      });
    }

    const device = await Device.findOne({
      $or: deviceIdentifierFilters(resolvedDeviceCode),
    });

    if (!device) {
      logSensor("found device", {
        requestedDeviceCode: resolvedDeviceCode,
        found: false,
      });
      logSensor("response status", {
        status: 404,
        message: "Device not found",
      });
      return res.status(404).json({
        success: false,
        message: "Device not found",
      });
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
      logSensor("response status", {
        status: 400,
        message:
          "temperature, smokeLevel, co2Level, lightLevel, and flameLevel must be numbers",
      });
      return res.status(400).json({
        success: false,
        message:
          "temperature, smokeLevel, co2Level, lightLevel, and flameLevel must be numbers",
      });
    }

    logSensor("found device", {
      id: device._id.toString(),
      deviceId: device.deviceId,
      deviceCode: device.deviceCode,
      roomId: device.roomId?.toString(),
      userId: device.userId?.toString(),
    });

    let thresholds = await ThresholdSetting.findOne({
      roomId: device.roomId,
    });

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

    logSensor("created reading", {
      id: reading._id.toString(),
      deviceId: reading.deviceId.toString(),
      temperature: reading.temperature,
      smokeLevel: reading.smokeLevel,
      humidity: reading.humidity,
      co2Level: reading.co2Level,
      lightLevel: reading.lightLevel,
      flameLevel: reading.flameLevel,
      flameDetected: reading.flameDetected,
      status: reading.status,
      createdAt: reading.createdAt,
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
          message: alertMessage,
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
        message: alertMessage,
      }).sort({ createdAt: -1 });

      if (activeAlert) {
        await Alert.findByIdAndUpdate(activeAlert._id, {
          ...snapshot,
          severity: "critical",
        });
      } else {
        alert = await Alert.create({
          userId: device.userId,
          roomId: device.roomId,
          deviceId: device._id,
          type,
          message: alertMessage,
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
          message: alertMessage,
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

    logSensor("response status", { status: 201 });
    res.status(201).json({
      success: true,
      data: populatedReading,
    });
  } catch (error) {
    logSensor("response status", {
      status: 500,
      message: error.message,
    });
    res.status(500).json({ success: false, message: error.message });
  }
};

const getDeviceReadings = async (req, res) => {
  try {
    const device = await findUserDevice(req.user.uid, req.params.deviceId);

    if (!device) {
      return res.json({ success: true, data: [] });
    }

    const readings = await SensorReading.find({
      deviceId: device._id,
    })
      .populate("deviceId")
      .sort({ createdAt: -1 });

    res.json({ success: true, data: readings });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getLatestReading = async (req, res) => {
  try {
    logSensor("latest reading request", {
      deviceId: req.params.deviceId,
    });

    const device = await findUserDevice(req.user.uid, req.params.deviceId);

    if (!device) {
      logSensor("latest reading response", {
        status: 200,
        deviceId: req.params.deviceId,
        readingId: null,
        message: "Device not found for current user",
      });
      return res.json({ success: true, data: null });
    }

    const reading = await SensorReading.findOne({
      deviceId: device._id,
    })
      .populate("deviceId")
      .sort({ createdAt: -1 });

    logSensor("latest reading response", {
      status: 200,
      deviceId: req.params.deviceId,
      readingId: reading?._id?.toString() ?? null,
      createdAt: reading?.createdAt ?? null,
    });
    res.json({ success: true, data: reading });
  } catch (error) {
    logSensor("latest reading response", {
      status: 500,
      deviceId: req.params.deviceId,
      message: error.message,
    });
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  addSensorReading,
  getDeviceReadings,
  getLatestReading,
};
