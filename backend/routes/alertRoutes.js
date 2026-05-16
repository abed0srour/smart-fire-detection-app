const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  getMyAlerts,
  markAlertAsRead,
  resolveAlert,
  requestEmergencyCall,
} = require("../controllers/alertController");

router.get("/", firebaseAuth, getMyAlerts);
router.post("/emergency-call", firebaseAuth, requestEmergencyCall);
router.patch("/:id/read", firebaseAuth, markAlertAsRead);
router.patch("/:id/resolve", firebaseAuth, resolveAlert);

module.exports = router;
