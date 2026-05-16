const { Server } = require("socket.io");

const admin = require("../config/firebase");
const User = require("../models/User");

let io = null;

const userRoom = (userId) => `user:${userId}`;

const tokenFromHandshake = (socket) => {
  const authToken = socket.handshake.auth?.token;
  if (authToken) {
    return authToken;
  }

  const authHeader = socket.handshake.headers?.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    return authHeader.split(" ")[1];
  }

  return null;
};

const initializeSocket = (server) => {
  io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  io.use(async (socket, next) => {
    try {
      const token = tokenFromHandshake(socket);
      if (!token) {
        return next(new Error("Authentication required"));
      }

      const decodedToken = await admin.auth().verifyIdToken(token);
      const user = await User.findOne({ firebaseUid: decodedToken.uid });

      if (!user) {
        return next(new Error("User profile not found"));
      }

      socket.firebaseUid = decodedToken.uid;
      socket.backendUserId = user._id.toString();
      return next();
    } catch (error) {
      return next(new Error("Unauthorized Firebase token"));
    }
  });

  io.on("connection", (socket) => {
    socket.join(userRoom(socket.backendUserId));
    socket.emit("socket:ready", {
      userId: socket.backendUserId,
      firebaseUid: socket.firebaseUid,
    });
  });

  return io;
};

const emitToUser = (userId, event, payload) => {
  if (!io || !userId) {
    return;
  }

  io.to(userRoom(userId.toString())).emit(event, payload);
};

module.exports = {
  initializeSocket,
  emitToUser,
};
