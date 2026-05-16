const express = require("express");
const router = express.Router();

const {
  addSensorReading,
  getDeviceReadings,
  getLatestReading,
} = require("../controllers/sensorController");

// IoT device sends data here. No Firebase auth because sensor device is not logged in.
router.post("/", addSensorReading);

// Flutter app reads data. Protected.
const firebaseAuth = require("../middleware/firebaseAuth");

router.get("/device/:deviceId", firebaseAuth, getDeviceReadings);
router.get("/latest/:deviceId", firebaseAuth, getLatestReading);

module.exports = router;