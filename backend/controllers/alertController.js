const User = require("../models/User");
const Alert = require("../models/Alert");
const Room = require("../models/Room");
const Device = require("../models/Device");
const { emitToUser } = require("../realtime/socket");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
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
      .sort({ createdAt: -1 });

    res.json({ success: true, data: alerts });
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
