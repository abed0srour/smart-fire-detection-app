const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const ThresholdSetting = require("../models/ThresholdSetting");
const Alert = require("../models/Alert");
const User = require("../models/User");

const calculateStatus = require("../utils/calculateStatus");
const sendNotification = require("../utils/sendNotification");
const { emitToUser } = require("../realtime/socket");
const { processSensorPayload } = require("../services/sensorProcessor");

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

const alertMessage = "Danger detected! Please check the room immediately.";

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

    const result = await processSensorPayload(req.body);

    logSensor("response status", { status: 201 });
    res.status(201).json({
      success: true,
      data: result.reading,
    });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    logSensor("response status", {
      status: statusCode,
      message: error.message,
    });
    res.status(statusCode).json({
      success: false,
      message: error.message,
    });
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
