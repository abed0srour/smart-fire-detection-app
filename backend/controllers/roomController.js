const User = require("../models/User");
const Room = require("../models/Room");
const { emitToUser } = require("../realtime/socket");

const getCurrentUser = async (firebaseUid) => {
  return await User.findOne({ firebaseUid });
};

const createRoom = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);
    const { name, location } = req.body;

    const room = await Room.create({
      userId: user._id,
      name,
      location,
    });

    emitToUser(user._id, "rooms:changed", {
      action: "room_created",
      room,
    });

    res.status(201).json({ success: true, data: room });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getMyRooms = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const rooms = await Room.find({ userId: user._id }).sort({
      createdAt: -1,
    });

    res.json({ success: true, data: rooms });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const updateRoom = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const room = await Room.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      req.body,
      { new: true }
    );

    if (room) {
      emitToUser(user._id, "rooms:changed", {
        action: "room_updated",
        room,
      });
    }

    res.json({ success: true, data: room });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const deleteRoom = async (req, res) => {
  try {
    const user = await getCurrentUser(req.user.uid);

    const room = await Room.findOneAndDelete({
      _id: req.params.id,
      userId: user._id,
    });

    if (room) {
      emitToUser(user._id, "rooms:changed", {
        action: "room_deleted",
        roomId: room._id.toString(),
      });
    }

    res.json({ success: true, message: "Room deleted successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createRoom,
  getMyRooms,
  updateRoom,
  deleteRoom,
};
