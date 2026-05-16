const User = require("../models/User");
const Room = require("../models/Room");
const Device = require("../models/Device");
const Alert = require("../models/Alert");
const SensorReading = require("../models/SensorReading");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const getDashboardStats = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const totalRooms = await Room.countDocuments({ userId: user._id });
    const totalDevices = await Device.countDocuments({ userId: user._id });
    const totalAlerts = await Alert.countDocuments({ userId: user._id });
    const unreadAlerts = await Alert.countDocuments({
      userId: user._id,
      isRead: false,
    });

    const devices = await Device.find({ userId: user._id }).select("_id");
    const deviceIds = devices.map((device) => device._id);

    const latestReading = await SensorReading.findOne({
      deviceId: { $in: deviceIds },
    })
      .sort({ createdAt: -1 })
      .populate("deviceId");

    res.json({
      success: true,
      data: {
        totalRooms,
        totalDevices,
        totalAlerts,
        unreadAlerts,
        latestReading,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getDashboardStats,
};