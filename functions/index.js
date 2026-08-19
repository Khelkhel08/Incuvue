const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");

initializeApp();
setGlobalOptions({maxInstances: 5, region: "us-central1"});

function createTransport() {
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass) return null;
  return nodemailer.createTransport({
    service: "gmail",
    auth: {user, pass},
  });
}

exports.onContactRequestCreated = onDocumentCreated(
    "contact_requests/{requestId}",
    async (event) => {
      const data = event.data?.data() || {};
      const adminEmail = process.env.ADMIN_EMAIL;
      const transporter = createTransport();

      if (!adminEmail || !transporter) {
        console.log("Email not sent: set ADMIN_EMAIL, SMTP_USER, and SMTP_PASS.");
        return;
      }

      const submitted = new Date().toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });

      await transporter.sendMail({
        from: process.env.SMTP_USER,
        to: adminEmail,
        subject: `New Contact Admin Request: ${data.concernType || "General"}`,
        text: [
          "New Contact Admin Request",
          "",
          `Concern Type: ${data.concernType || ""}`,
          `User Email: ${data.email || ""}`,
          `Description: ${data.description || ""}`,
          `Submitted: ${submitted}`,
        ].join("\n"),
      });
    },
);

exports.onIncubatorVisionUpdated = onDocumentUpdated(
    "incubators/incubator_1",
    async (event) => {
      const before = event.data?.before.data() || {};
      const after = event.data?.after.data() || {};
      const beforeAt = before.vision?.analyzedAt?.toMillis?.() || before.vision?.analyzedAt;
      const afterAt = after.vision?.analyzedAt?.toMillis?.() || after.vision?.analyzedAt;
      if (!afterAt || beforeAt === afterAt) return;

      const db = getFirestore();
      await db.collection("egg_detections").add({
        batchNumber: after.currentBatchNumber || "",
        trayNumber: after.currentTrayNumber || "1",
        imageUrl: after.vision?.imageUrl || "",
        detectedCount: after.vision?.totalEggs || 0,
        detectionResult: {
          normalEggs: after.vision?.normalEggs || 0,
          crackedEggs: after.vision?.crackedEggs || 0,
          detections: after.vision?.detections || [],
        },
        confidence: after.vision?.confidenceThreshold || 0,
        capturedAt: after.vision?.analyzedAt || FieldValue.serverTimestamp(),
      });
    },
);
