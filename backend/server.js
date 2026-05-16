const express = require("express");
const http = require("http");
const cors = require("cors");
const morgan = require("morgan");
require("dotenv").config();

const connectDB = require("./config/db");
require("./config/firebase");

const userRoutes = require("./routes/userRoutes");
const roomRoutes = require("./routes/roomRoutes");
const deviceRoutes = require("./routes/deviceRoutes");
const sensorRoutes = require("./routes/sensorRoutes");
const alertRoutes = require("./routes/alertRoutes");
const emergencyContactRoutes = require("./routes/emergencyContactRoutes");
const thresholdRoutes = require("./routes/thresholdRoutes");
const safetyTipRoutes = require("./routes/safetyTipRoutes");
const maintenanceRoutes = require("./routes/maintenanceRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const { initializeSocket } = require("./realtime/socket");

const app = express();
const server = http.createServer(app);

connectDB();
initializeSocket(server);

app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Fire Detector Backend API is running",
  });
});

app.use("/api/users", userRoutes);
app.use("/api/rooms", roomRoutes);
app.use("/api/devices", deviceRoutes);
app.use("/api/sensors", sensorRoutes);
app.use("/api/alerts", alertRoutes);
app.use("/api/emergency-contacts", emergencyContactRoutes);
app.use("/api/thresholds", thresholdRoutes);
app.use("/api/safety-tips", safetyTipRoutes);
app.use("/api/maintenance", maintenanceRoutes);
app.use("/api/dashboard", dashboardRoutes);

const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
