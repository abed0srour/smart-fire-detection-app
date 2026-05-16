const express = require("express");
const router = express.Router();

const firebaseAuth = require("../middleware/firebaseAuth");

const {
  saveUserProfile,
  getMyProfile,
} = require("../controllers/userController");

router.post("/profile", firebaseAuth, saveUserProfile);
router.get("/profile", firebaseAuth, getMyProfile);

module.exports = router;