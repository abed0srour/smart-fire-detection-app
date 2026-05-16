const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createOrUpdateThreshold,
  getThresholdByRoom,
} = require("../controllers/thresholdController");

router.post("/", firebaseAuth, createOrUpdateThreshold);
router.get("/room/:roomId", firebaseAuth, getThresholdByRoom);

module.exports = router;