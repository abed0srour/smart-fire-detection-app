const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const ThresholdSetting = require("../models/ThresholdSetting");
const Alert = require("../models/Alert");
const User = require("../models/User");

const calculateStatus = require("../utils/calculateStatus");
const sendNotification = require("../utils/sendNotification");
const { emitToUser } = require("../realtime/socket");

const addSensorReading = async (req, res) => {
  try {
    const {
      deviceId,
      deviceCode,
      temperature,
      smokeLevel,
      co2Level,
      coLevel,
      flameDetected,
      batteryLevel,
    } = req.body;

    const resolvedDeviceCode = deviceCode || deviceId;
    const resolvedCo2Level = co2Level ?? coLevel ?? 0;

    if (!resolvedDeviceCode) {
      return res.status(400).json({
        success: false,
        message: "deviceId or deviceCode is required",
      });
    }

    const device = await Device.findOne({
      $or: [
        { deviceId: resolvedDeviceCode },
        { deviceCode: resolvedDeviceCode },
      ],
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: "Device not found",
      });
    }

    let thresholds = await ThresholdSetting.findOne({
      roomId: device.roomId,
    });

    if (!thresholds) {
      thresholds = {
        temperatureWarning: 40,
        temperatureDanger: 60,
        smokeWarning: 40,
        smokeDanger: 70,
        co2Warning: 700,
        co2Danger: 1000,
      };
    }

    const status = calculateStatus(
      {
        temperature,
        smokeLevel,
        co2Level: resolvedCo2Level,
        flameDetected,
      },
      thresholds
    );

    const reading = await SensorReading.create({
      deviceId: device._id,
      temperature,
      smokeLevel,
      co2Level: resolvedCo2Level,
      flameDetected,
      status,
    });

    device.isOnline = true;
    device.lastSeen = new Date();

    if (batteryLevel !== undefined) {
      device.batteryLevel = batteryLevel;
    }

    await device.save();

    let alert = null;

    if (status === "danger") {
      alert = await Alert.create({
        userId: device.userId,
        roomId: device.roomId,
        deviceId: device._id,
        type: flameDetected ? "fire" : "temperature",
        message: "Danger detected! Please check the room immediately.",
        severity: "critical",
      });

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
    const populatedAlert = alert ? await alert.populate("roomId deviceId") : null;
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

    res.status(201).json({
      success: true,
      data: populatedReading,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getDeviceReadings = async (req, res) => {
  try {
    const readings = await SensorReading.find({
      deviceId: req.params.deviceId,
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
    const reading = await SensorReading.findOne({
      deviceId: req.params.deviceId,
    })
      .populate("deviceId")
      .sort({ createdAt: -1 });

    res.json({ success: true, data: reading });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  addSensorReading,
  getDeviceReadings,
  getLatestReading,
};
