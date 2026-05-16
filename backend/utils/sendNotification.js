const admin = require("../config/firebase");

const sendNotification = async (fcmToken, title, body, data = {}) => {
  try {
    if (!fcmToken) {
      console.log("No FCM token found");
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data,
    };

    const response = await admin.messaging().send(message);

    console.log("Notification sent successfully:", response);
  } catch (error) {
    console.error("Notification error:", error.message);
  }
};

module.exports = sendNotification;