const functions = require("firebase-functions/v1"); // <-- This is the magic fix!
const admin = require("firebase-admin");

// Initialize the admin permissions to read your database
admin.initializeApp();

exports.sendPaymentNotification = functions.firestore
  .document("direct_payments/{paymentId}")
  .onCreate(async (snap, context) => {
    // 1. Grab the data from the newly created payment
    const paymentData = snap.data();
    const friendName = paymentData.friendName;
    const amount = paymentData.amount;
    const youPaid = paymentData.youPaid;
    const senderId = paymentData.userId;

    console.log(`New payment recorded by ${senderId} for ${friendName}`);

    try {
      // 2. Look up the person who RECORDED the payment to get their name
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const senderName = senderDoc.data().name;

      // 3. Look up the FRIEND receiving the notification to get their Token
      const friendQuery = await admin.firestore()
        .collection("users")
        .where("name", "==", friendName)
        .limit(1)
        .get();

      if (friendQuery.empty) {
        console.log("Friend not found in database. Skipping notification.");
        return null;
      }

      const friendDoc = friendQuery.docs[0];
      const fcmToken = friendDoc.data().fcmToken;

      if (!fcmToken) {
        console.log("Friend does not have an FCM token yet. Skipping.");
        return null;
      }

      // 4. Construct the Notification Message!
      let title = "New SplitSathi Activity 💸";
      let body = "";
      
      if (youPaid) {
          body = `${senderName} paid you ₹${amount}.`;
      } else {
          body = `You owe ${senderName} ₹${amount}.`;
      }

      const payload = {
        notification: {
          title: title,
          body: body,
        },
        token: fcmToken,
      };

      // 5. Send it to their phone!
      await admin.messaging().send(payload);
      console.log("BOOM! Notification sent successfully!");

    } catch (error) {
      console.error("Error sending notification:", error);
    }
    
    return null;
  });