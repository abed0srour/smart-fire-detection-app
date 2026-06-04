const User = require("../models/User");
const Alert = require("../models/Alert");
const Room = require("../models/Room");
const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const { emitToUser } = require("../realtime/socket");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const deviceObjectId = (alert) => {
  return alert.deviceId?._id ?? alert.deviceId;
};

const alertEventKey = (alert) => {
  const deviceId = deviceObjectId(alert)?.toString() ?? "unknown-device";
  const resolutionKey = alert.isResolved
    ? alert.resolvedAt?.toISOString?.() ?? alert.updatedAt?.toISOString?.()
    : "active";

  return [deviceId, alert.type, alert.severity, resolutionKey].join(":");
};

const readingSnapshot = (reading) => {
  if (!reading) {
    return {};
  }

  return {
    temperature: reading.temperature,
    smokeLevel: reading.smokeLevel,
    humidity: reading.humidity,
    co2Level: reading.co2Level,
    lightLevel: reading.lightLevel,
    flameLevel: reading.flameLevel,
    flameDetected: reading.flameDetected,
    status: reading.status,
    readingId: reading._id,
  };
};

const fallbackReadingForAlert = async (alert) => {
  const id = deviceObjectId(alert);

  if (!id) {
    return null;
  }

  return await SensorReading.findOne({
    deviceId: id,
    createdAt: { $lte: alert.createdAt },
  })
    .sort({ createdAt: -1 })
    .populate("deviceId");
};

const alertResponse = async (alert) => {
  const item = alert.toObject();
  const populatedReading = item.readingId?.temperature
    ? item.readingId
    : null;
  const fallbackReading = populatedReading
    ? null
    : await fallbackReadingForAlert(alert);
  const reading = populatedReading || fallbackReading;

  return {
    ...item,
    ...readingSnapshot(reading),
    temperature: item.temperature ?? reading?.temperature ?? 0,
    smokeLevel: item.smokeLevel ?? reading?.smokeLevel ?? 0,
    humidity: item.humidity ?? reading?.humidity ?? 0,
    co2Level: item.co2Level ?? reading?.co2Level ?? 0,
    lightLevel: item.lightLevel ?? reading?.lightLevel ?? 0,
    flameLevel: item.flameLevel ?? reading?.flameLevel ?? 0,
    flameDetected: item.flameDetected ?? reading?.flameDetected ?? false,
    status: item.status ?? reading?.status ?? item.message,
  };
};

const getMyAlerts = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User profile not found",
      });
    }

    const alerts = await Alert.find({ userId: user._id })
      .populate("roomId")
      .populate("deviceId")
      .populate("readingId")
      .sort({ createdAt: -1 });
    const seenEvents = new Set();
    const eventAlerts = [];

    for (const alert of alerts) {
      const key = alertEventKey(alert);

      if (seenEvents.has(key)) {
        continue;
      }

      seenEvents.add(key);
      eventAlerts.push(await alertResponse(alert));
    }

    res.json({ success: true, data: eventAlerts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const markAlertAsRead = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User profile not found",
      });
    }

    const alert = await Alert.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      { isRead: true },
      { new: true }
    );

    res.json({ success: true, data: alert });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const resolveAlert = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User profile not found",
      });
    }

    const alert = await Alert.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      {
        isResolved: true,
        resolvedAt: new Date(),
      },
      { new: true }
    );

    res.json({ success: true, data: alert });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const requestEmergencyCall = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User profile not found",
      });
    }

    const { source, roomId, deviceId, deviceCode } = req.body;

    let room = roomId
      ? await Room.findOne({ _id: roomId, userId: user._id })
      : await Room.findOne({ userId: user._id }).sort({ createdAt: -1 });

    if (!room) {
      room = await Room.create({
        userId: user._id,
        name: "Main Room",
        location: "Default",
      });
    }

    let device = null;

    if (deviceId) {
      const deviceFilters = [{ deviceId }, { deviceCode: deviceId }];
      if (/^[0-9a-fA-F]{24}$/.test(deviceId)) {
        deviceFilters.push({ _id: deviceId });
      }

      device = await Device.findOne({
        userId: user._id,
        $or: deviceFilters,
      });
    }

    if (!device && deviceCode) {
      device = await Device.findOne({
        userId: user._id,
        $or: [{ deviceId: deviceCode }, { deviceCode }],
      });
    }

    if (!device) {
      device = await Device.findOne({ userId: user._id }).sort({
        createdAt: -1,
      });
    }

    if (!device) {
      const fallbackDeviceId = deviceCode || "MASTER_ROOM";
      device = await Device.create({
        userId: user._id,
        roomId: room._id,
        deviceId: fallbackDeviceId,
        deviceCode: fallbackDeviceId,
        name: "Fire Detector Device",
        isOnline: true,
        lastSeen: new Date(),
      });
    }

    const alert = await Alert.create({
      userId: user._id,
      roomId: room._id,
      deviceId: device._id,
      type: "fire",
      message: `Emergency call requested from ${source || "app"}.`,
      severity: "critical",
    });

    const populatedAlert = await alert.populate("roomId deviceId");
    emitToUser(user._id, "alert:created", {
      alert: populatedAlert,
      deviceId: device._id.toString(),
      deviceCode: device.deviceCode || device.deviceId,
    });

    res.status(201).json({ success: true, data: populatedAlert });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getMyAlerts,
  markAlertAsRead,
  resolveAlert,
  requestEmergencyCall,
};
