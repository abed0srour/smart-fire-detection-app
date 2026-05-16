const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createEmergencyContact,
  getMyEmergencyContacts,
  updateEmergencyContact,
  deleteEmergencyContact,
} = require("../controllers/emergencyContactController");

router.post("/", firebaseAuth, createEmergencyContact);
router.get("/", firebaseAuth, getMyEmergencyContacts);
router.put("/:id", firebaseAuth, updateEmergencyContact);
router.delete("/:id", firebaseAuth, deleteEmergencyContact);

module.exports = router;