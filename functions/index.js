const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Only initialize the app globally to prevent timeouts
admin.initializeApp();

/**
 * Helper function to send a notification and save it to the user's subcollection.
 */
async function sendAndSaveNotification(userId, title, body) {
  // Initialize services inside the function ("lazy initialization")
  const db = admin.firestore();
  const messaging = admin.messaging();

  const userDocRef = db.collection("users").doc(userId);
  const userDoc = await userDocRef.get();

  if (!userDoc.exists) {
    console.log(`User ${userId} not found.`);
    return;
  }

  const userData = userDoc.data();
  const fcmToken = userData.fcmToken;

  try {
    await userDocRef.collection("notifications").add({
      title: title,
      body: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
    console.log(`Notification saved for user: ${userId}`);
  } catch (error) {
    console.error("Error saving notification to Firestore:", error);
  }

  if (fcmToken) {
    const payload = {
      notification: { title, body },
      token: fcmToken,
      data: {
        type: "leave_request", // Add custom data for handling clicks in the app
      },
    };
    try {
      await messaging.send(payload);
      console.log(`Push notification sent to user: ${userId}`);
    } catch (error) {
      console.error("Error sending push notification:", error);
    }
  } else {
    console.log(`User ${userId} does not have an FCM token.`);
  }
}

/**
 * HTTPS Callable function for an admin to pre-approve an employee.
 * This is the correct function for your new OTP flow.
 */
exports.createEmployee = functions.https.onCall(async (data, context) => {
  // Check if the user is an authenticated admin
  if (!context.auth || !context.auth.token.role === 'admin') {
    throw new functions.https.HttpsError(
        'permission-denied',
        'You must be an admin to create users.'
    );
  }

  const { name, designation, department, workLocation, reportsTo, phone } = data;

  if (!name || !phone) {
    throw new functions.https.HttpsError(
        'invalid-argument',
        'Full Name and Phone Number are required.'
    );
  }
  
  const db = admin.firestore();

  try {
    // Create a "pre-approved" document with the phone number as the ID
    await db.collection("users").doc(phone).set({
        name: name,
        designation: designation || "",
        department: department || "",
        workLocation: workLocation || "",
        reportsTo: reportsTo || "nil",
        phone: phone,
        role: 'employee', // Default role
        status: 'pending_verification', // Initial status
        deviceId: "",
        fcmToken: ""
    });

    return { success: true, message: `Successfully created pre-approved profile for ${name}.` };

  } catch (error) {
    console.error("Error creating pre-approved profile:", error);
    throw new functions.https.HttpsError(
        'internal',
        'An error occurred while creating the profile: ' + error.message
    );
  }
});


/**
 * Triggers when a new Firebase user is created (by your app's OTP flow).
 * It links the Auth user to the pre-approved Firestore profile.
 */
exports.setupNewUser = functions.auth.user().onCreate(async (user) => {
    if (!user.phoneNumber) {
        console.log("User does not have a phone number, skipping setup.");
        return null;
    }
    const db = admin.firestore();
    const phone = user.phoneNumber;

    const preApprovedDocRef = db.collection('users').doc(phone);
    const preApprovedDoc = await preApprovedDocRef.get();

    if (!preApprovedDoc.exists) {
        console.log(`No pre-approved profile for ${phone}. Deleting auth user for security.`);
        await admin.auth().deleteUser(user.uid);
        return null;
    }

    const profileData = preApprovedDoc.data();
    
    // Set final status and create the permanent user document
    profileData.status = 'approved';
    await db.collection('users').doc(user.uid).set(profileData);
    
    // Delete the temporary pre-approved document
    await preApprovedDocRef.delete();

    console.log(`Successfully set up new user: ${user.uid} for ${profileData.name}`);
    return null;
});


/**
 * Triggers when a new leave request is created and notifies the manager.
 * MODIFIED: This function now correctly uses the 'reportsTo' system.
 */
exports.sendLeaveRequestNotification = functions.firestore
  .document("leaves/{leaveId}")
  .onCreate(async (snap, context) => {
    const leaveData = snap.data();
    console.log(`New leave request created by: ${leaveData.name}`);
    
    const db = admin.firestore();

    // 1. Get the employee's user document to find their manager
    const employeeId = leaveData.uid;
    const employeeDoc = await db.collection('users').doc(employeeId).get();

    if (!employeeDoc.exists) {
      console.error(`Could not find user document for employee: ${employeeId}`);
      return null;
    }

    const managerId = employeeDoc.data().reportsTo;

    // 2. Check if a manager is assigned
    if (managerId && managerId !== 'nil') {
      const title = "New Leave Request";
      const body = `${leaveData.name} has applied for ${leaveData.type}.`;
      
      // 3. Send the notification to the manager
      console.log(`Found manager (${managerId}) for employee ${leaveData.name}. Sending notification.`);
      await sendAndSaveNotification(managerId, title, body);

    } else {
      console.log(`No manager found for employee ${leaveData.name}. No notification sent.`);
    }
    
    return null;
  });


/**
 * Triggers when a leave request status is updated and notifies the employee.
 */
exports.onLeaveStatusUpdate = functions.firestore
  .document("leaves/{leaveId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only send a notification if the status changes from 'pending'
    if (beforeData.status === 'pending' && beforeData.status !== afterData.status) {
      const employeeId = afterData.uid;
      const status = afterData.status; // e.g., 'approved' or 'rejected'
      
      await sendAndSaveNotification(
        employeeId,
        `Leave Request ${status.charAt(0).toUpperCase() + status.slice(1)}`, // Capitalizes the status
        `Your request for ${afterData.type} has been ${status}.`
      );
    }
    return null;
  });


/**
 * Schedules a cron job for check-in reminders.
 */
exports.sendCheckInReminder = functions.pubsub
  .schedule("30 9 * * 1-5")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const db = admin.firestore();
    console.log("Running daily check-in reminder job.");
    // ... your reminder logic
    return null;
  });

/**
 * Schedules a cron job for check-out reminders.
 */
exports.sendCheckOutReminder = functions.pubsub
  .schedule("30 18 * * 1-5")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const db = admin.firestore();
    console.log("Running daily check-out reminder job.");
    // ... your reminder logic
    return null;
  });