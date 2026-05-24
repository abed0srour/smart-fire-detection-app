const User = require("../models/User");
const Device = require("../models/Device");
const SensorReading = require("../models/SensorReading");
const { emitToUser } = require("../realtime/socket");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const createDevice = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User profile not found",
      });
    }

    const { roomId, deviceId, deviceCode, name, batteryLevel } = req.body;
    const resolvedDeviceId = deviceId || deviceCode;

    if (!resolvedDeviceId) {
      return res.status(400).json({
        success: false,
        message: "deviceId is required",
      });
    }

    const device = await Device.create({
      userId: user._id,
      roomId,
      deviceId: resolvedDeviceId,
      deviceCode: deviceCode || resolvedDeviceId,
      name,
      batteryLevel,
      isOnline: true,
      lastSeen: new Date(),
    });

    emitToUser(user._id, "rooms:changed", {
      action: "device_created",
      device,
    });

    res.status(201).json({ success: true, data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getMyDevices = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const devices = await Device.find({ userId: user._id })
      .populate("roomId")
      .sort({ createdAt: -1 });

    const deviceIds = devices.map((device) => device._id);
    const readings = await SensorReading.find({ deviceId: { $in: deviceIds } })
      .populate("deviceId")
      .sort({ createdAt: -1 });
    const latestReadingByDevice = new Map();

    readings.forEach((reading) => {
      const id =
        reading.deviceId?._id?.toString() ?? reading.deviceId?.toString();
      if (id && !latestReadingByDevice.has(id)) {
        latestReadingByDevice.set(id, reading);
      }
    });

    const data = devices.map((device) => {
      const item = device.toObject();
      item.latestReading =
        latestReadingByDevice.get(device._id.toString()) ?? null;
      return item;
    });

    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const updateDevice = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const device = await Device.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      req.body,
      { new: true }
    );

    if (device) {
      emitToUser(user._id, "device:updated", { device });
      emitToUser(user._id, "rooms:changed", {
        action: "device_updated",
        device,
      });
    }

    res.json({ success: true, data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const deleteDevice = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const device = await Device.findOneAndDelete({
      _id: req.params.id,
      userId: user._id,
    });

    if (device) {
      emitToUser(user._id, "rooms:changed", {
        action: "device_deleted",
        deviceId: device._id.toString(),
      });
    }

    res.json({ success: true, message: "Device deleted successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createDevice,
  getMyDevices,
  updateDevice,
  deleteDevice,
};
