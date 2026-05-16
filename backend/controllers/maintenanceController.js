const User = require("../models/User");
const MaintenanceReminder = require("../models/MaintenanceReminder");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const createMaintenanceReminder = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const reminder = await MaintenanceReminder.create({
      userId: user._id,
      ...req.body,
    });

    res.status(201).json({ success: true, data: reminder });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getMyMaintenanceReminders = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const reminders = await MaintenanceReminder.find({
      userId: user._id,
    })
      .populate("deviceId")
      .sort({ reminderDate: 1 });

    res.json({ success: true, data: reminders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const completeMaintenanceReminder = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const reminder = await MaintenanceReminder.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      {
        isCompleted: true,
        completedAt: new Date(),
      },
      { new: true }
    );

    res.json({ success: true, data: reminder });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const deleteMaintenanceReminder = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    await MaintenanceReminder.findOneAndDelete({
      _id: req.params.id,
      userId: user._id,
    });

    res.json({
      success: true,
      message: "Maintenance reminder deleted successfully",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createMaintenanceReminder,
  getMyMaintenanceReminders,
  completeMaintenanceReminder,
  deleteMaintenanceReminder,
};