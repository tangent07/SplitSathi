const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Initialize the admin permissions to read your database
admin.initializeApp();

// ─────────────────────────────────────────────────────────────
// 1. DIRECT PAYMENT NOTIFICATIONS
// ─────────────────────────────────────────────────────────────
exports.sendPaymentNotification = functions.firestore
  .document("direct_payments/{paymentId}")
  .onCreate(async (snap, context) => {
    const paymentData = snap.data();
    const friendName = paymentData.friendName;
    const amount = paymentData.amount;
    const youPaid = paymentData.youPaid;
    const senderId = paymentData.userId;

    console.log(`New payment recorded by ${senderId} for ${friendName}`);

    try {
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const senderName = senderDoc.data().name;

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

      let title = "New SplitSathi Activity 💸";
      let body = youPaid ? `${senderName} paid you ₹${amount}.` : `You owe ${senderName} ₹${amount}.`;

      const payload = {
        notification: { title: title, body: body },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      console.log("BOOM! Direct Notification sent successfully!");

    } catch (error) {
      console.error("Error sending notification:", error);
    }
    
    return null;
  });

// ─────────────────────────────────────────────────────────────
// 2. GROUP EXPENSE NOTIFICATIONS
// ─────────────────────────────────────────────────────────────
exports.sendGroupExpenseNotification = functions.firestore
  .document("groups/{groupId}/expenses/{expenseId}")
  .onCreate(async (snap, context) => {
    const expenseData = snap.data();
    const paidBy = expenseData.paidBy;
    const amount = expenseData.amount;

    try {
      const groupId = context.params.groupId;
      const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
      
      if (!groupDoc.exists) return null;

      const groupName = groupDoc.data().name;
      const members = groupDoc.data().members || [];
      const creatorId = groupDoc.data().createdBy; // <-- WE GRAB THE CREATOR'S ID!

      console.log(`New expense in ${groupName} paid by ${paidBy}`);

      // Filter out the person who paid. (We DO NOT filter out "You" anymore!)
      const usersToNotify = members.filter(member => member !== paidBy);

      if (usersToNotify.length === 0) {
        console.log("No one else to notify in this group.");
        return null;
      }

      const tokens = [];
      for (const memberName of usersToNotify) {
        if (memberName === "You") {
          // If the member is "You", look up the group creator's exact FCM Token!
          const creatorDoc = await admin.firestore().collection("users").doc(creatorId).get();
          if (creatorDoc.exists && creatorDoc.data().fcmToken) {
            tokens.push(creatorDoc.data().fcmToken);
          }
        } else {
          // Otherwise, look them up by their normal name
          const userQuery = await admin.firestore()
            .collection("users")
            .where("name", "==", memberName)
            .limit(1)
            .get();

          if (!userQuery.empty) {
            const token = userQuery.docs[0].data().fcmToken;
            if (token) tokens.push(token);
          }
        }
      }

      if (tokens.length === 0) {
        console.log("No valid tokens found for group members.");
        return null;
      }

      const message = {
        notification: {
          title: `${groupName} 🧾`,
          body: `${paidBy} added a ₹${amount} expense.`,
        },
        tokens: tokens, // Multicast array
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`BOOM! Successfully sent ${response.successCount} group messages.`);

    } catch (error) {
      console.error("Error sending group notification:", error);
    }

    return null;
  });