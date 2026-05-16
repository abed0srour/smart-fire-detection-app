const mongoose = require("mongoose");

const deviceSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    roomId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      required: true,
    },

    deviceId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },

    deviceCode: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },

    name: {
      type: String,
      default: "Fire Detector Device",
    },

    isOnline: {
      type: Boolean,
      default: false,
    },

    batteryLevel: {
      type: Number,
      default: 100,
    },

    alarmMuted: {
      type: Boolean,
      default: false,
    },

    lastSeen: {
      type: Date,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Device", deviceSchema);
