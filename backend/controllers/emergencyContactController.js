const User = require("../models/User");
const EmergencyContact = require("../models/EmergencyContact");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const createEmergencyContact = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const contact = await EmergencyContact.create({
      userId: user._id,
      ...req.body,
    });

    res.status(201).json({ success: true, data: contact });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getMyEmergencyContacts = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const contacts = await EmergencyContact.find({
      userId: user._id,
    }).sort({ isPrimary: -1, createdAt: -1 });

    res.json({ success: true, data: contacts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const updateEmergencyContact = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const contact = await EmergencyContact.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      req.body,
      { new: true }
    );

    res.json({ success: true, data: contact });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const deleteEmergencyContact = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    await EmergencyContact.findOneAndDelete({
      _id: req.params.id,
      userId: user._id,
    });

    res.json({
      success: true,
      message: "Emergency contact deleted successfully",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createEmergencyContact,
  getMyEmergencyContacts,
  updateEmergencyContact,
  deleteEmergencyContact,
};