const mongoose = require("mongoose");

const thresholdSettingSchema = new mongoose.Schema(
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

    temperatureWarning: {
      type: Number,
      default: 40,
    },

    temperatureDanger: {
      type: Number,
      default: 60,
    },

    smokeWarning: {
      type: Number,
      default: 40,
    },

    smokeDanger: {
      type: Number,
      default: 70,
    },

    co2Warning: {
      type: Number,
      default: 700,
    },

    co2Danger: {
      type: Number,
      default: 1000,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model(
  "ThresholdSetting",
  thresholdSettingSchema
);
