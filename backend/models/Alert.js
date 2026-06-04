const mongoose = require("mongoose");

const alertSchema = new mongoose.Schema(
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
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: true,
    },

    readingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "SensorReading",
    },

    type: {
      type: String,
      enum: ["fire", "smoke", "co2", "temperature", "light", "device_offline"],
      required: true,
    },

    message: {
      type: String,
      required: true,
    },

    severity: {
      type: String,
      enum: ["low", "medium", "high", "critical"],
      default: "medium",
    },

    temperature: {
      type: Number,
    },

    smokeLevel: {
      type: Number,
    },

    humidity: {
      type: Number,
    },

    co2Level: {
      type: Number,
    },

    lightLevel: {
      type: Number,
    },

    flameLevel: {
      type: Number,
    },

    flameDetected: {
      type: Boolean,
    },

    status: {
      type: String,
      enum: ["safe", "warning", "danger"],
    },

    isRead: {
      type: Boolean,
      default: false,
    },

    isResolved: {
      type: Boolean,
      default: false,
    },

    resolvedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Alert", alertSchema);
