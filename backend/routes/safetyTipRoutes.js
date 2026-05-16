const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createSafetyTip,
  getSafetyTips,
} = require("../controllers/safetyTipController");

// Later you can make createSafetyTip admin-only.
// For now, protected is enough.
router.post("/", firebaseAuth, createSafetyTip);

// Flutter can read safety tips.
router.get("/", firebaseAuth, getSafetyTips);

module.exports = router;