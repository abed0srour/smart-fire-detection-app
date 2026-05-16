const mongoose = require("mongoose");

const safetyTipSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
    },

    description: {
      type: String,
      required: true,
    },

    category: {
      type: String,
      enum: ["fire", "smoke", "co2", "general"],
      default: "general",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("SafetyTip", safetyTipSchema);