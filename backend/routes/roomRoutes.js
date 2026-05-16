const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  createRoom,
  getMyRooms,
  updateRoom,
  deleteRoom,
} = require("../controllers/roomController");

router.post("/", firebaseAuth, createRoom);
router.get("/", firebaseAuth, getMyRooms);
router.put("/:id", firebaseAuth, updateRoom);
router.delete("/:id", firebaseAuth, deleteRoom);

module.exports = router;