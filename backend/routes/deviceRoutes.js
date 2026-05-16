const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createDevice,
  getMyDevices,
  updateDevice,
  deleteDevice,
} = require("../controllers/deviceController");

router.post("/", firebaseAuth, createDevice);
router.get("/", firebaseAuth, getMyDevices);
router.put("/:id", firebaseAuth, updateDevice);
router.delete("/:id", firebaseAuth, deleteDevice);

module.exports = router;