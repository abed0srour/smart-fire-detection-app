const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createMaintenanceReminder,
  getMyMaintenanceReminders,
  completeMaintenanceReminder,
  deleteMaintenanceReminder,
} = require("../controllers/maintenanceController");

router.post("/", firebaseAuth, createMaintenanceReminder);
router.get("/", firebaseAuth, getMyMaintenanceReminders);
router.patch("/:id/complete", firebaseAuth, completeMaintenanceReminder);
router.delete("/:id", firebaseAuth, deleteMaintenanceReminder);

module.exports = router;