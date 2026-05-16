const User = require("../models/User");

const saveUserProfile = async (req, res) => {
  try {
    const { fullName, email, phone, address, fcmToken } = req.body;

    const firebaseUid = req.user.uid;

    let user = await User.findOne({ firebaseUid });

    if (user) {
      user.fullName = fullName || user.fullName;
      user.email = email || user.email;
      user.phone = phone || user.phone;
      user.address = address || user.address;
      user.fcmToken = fcmToken || user.fcmToken;

      await user.save();
    } else {
      user = await User.create({
        firebaseUid,
        fullName,
        email,
        phone,
        address,
        fcmToken,
      });
    }

    res.status(200).json({
      success: true,
      message: "User profile saved successfully",
      data: user,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

const getMyProfile = async (req, res) => {
  try {
    const user = await User.findOne({
      firebaseUid: req.user.uid,
    });

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  saveUserProfile,
  getMyProfile,
};