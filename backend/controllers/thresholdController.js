const User = require("../models/User");
const ThresholdSetting = require("../models/ThresholdSetting");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const createOrUpdateThreshold = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);
    const { roomId } = req.body;

    const threshold = await ThresholdSetting.findOneAndUpdate(
      { userId: user._id, roomId },
      {
        userId: user._id,
        ...req.body,
      },
      { new: true, upsert: true }
    );

    res.json({ success: true, data: threshold });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getThresholdByRoom = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const threshold = await ThresholdSetting.findOne({
      userId: user._id,
      roomId: req.params.roomId,
    });

    res.json({ success: true, data: threshold });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createOrUpdateThreshold,
  getThresholdByRoom,
};