const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  getDashboardStats,
} = require("../controllers/dashboardController");

router.get("/stats", firebaseAuth, getDashboardStats);

module.exports = router;