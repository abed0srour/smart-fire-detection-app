const mongoose = require("mongoose");

const sensorReadingSchema = new mongoose.Schema(
  {
    deviceId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: true,
    },

    temperature: {
      type: Number,
      required: true,
    },

    smokeLevel: {
      type: Number,
      required: true,
    },

    humidity: {
      type: Number,
      default: 0,
    },

    co2Level: {
      type: Number,
      required: true,
    },

    lightLevel: {
      type: Number,
      default: 0,
    },

    flameLevel: {
      type: Number,
      default: 0,
    },

    flameDetected: {
      type: Boolean,
      default: false,
    },

    status: {
      type: String,
      enum: ["safe", "warning", "danger"],
      default: "safe",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("SensorReading", sensorReadingSchema);
