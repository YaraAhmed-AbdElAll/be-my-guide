const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNewRequestNotification = functions.firestore
    .document("requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const requestData = snapshot.data();
        const userType = requestData.userType; // 'blind' or 'deaf'
        const userName = requestData.userName || "Someone";

        let topic = "";
        let title = "";
        let body = "";

        if (userType === "blind") {
            topic = "topic_volunteer";
            title = "New Visual Assistance Request";
            body = `${userName} needs visual assistance!`;
        } else if (userType === "deaf") {
            topic = "topic_sign_language_expert";
            title = "New Sign Language Request";
            body = `${userName} needs sign language assistance!`;
        } else {
            console.log("Unknown user type or no matching topic:", userType);
            return null;
        }

        const message = {
            notification: {
                title: title,
                body: body,
            },
            topic: topic,
            data: {
                requestId: context.params.requestId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
        };

        try {
            const response = await admin.messaging().send(message);
            console.log("Successfully sent message:", response);
            return response;
        } catch (error) {
            console.log("Error sending message:", error);
            return null;
        }
    });
