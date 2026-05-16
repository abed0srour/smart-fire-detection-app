const SafetyTip = require("../models/SafetyTip");

const createSafetyTip = async (req, res) => {
  try {
    const tip = await SafetyTip.create(req.body);

    res.status(201).json({ success: true, data: tip });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const getSafetyTips = async (req, res) => {
  try {
    const filter = {};

    if (req.query.category) {
      filter.category = req.query.category;
    }

    const tips = await SafetyTip.find(filter).sort({ createdAt: -1 });

    res.json({ success: true, data: tips });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  createSafetyTip,
  getSafetyTips,
};