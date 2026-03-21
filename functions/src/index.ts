/**
 * Firebase Cloud Functions for Lumina App
 *
 * Features:
 * - Email notifications when new feedback is received
 * - Caregiver notifications for geofence events
 * - Medication reminder alerts
 * - Error reporting
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import * as https from 'https';

admin.initializeApp();

// ============================================================================
// CONFIGURATION
// ============================================================================

// Email configuration
// Set these in Firebase Functions config:
// firebase functions:config:set email.user="your-email@gmail.com" email.pass="your-app-password"
// firebase functions:config:set email.admin="admin@yourcompany.com"
const EMAIL_USER = functions.config().email?.user || process.env.EMAIL_USER;
const EMAIL_PASS = functions.config().email?.pass || process.env.EMAIL_PASS;
const ADMIN_EMAIL = functions.config().email?.admin || process.env.ADMIN_EMAIL || EMAIL_USER;

// Create reusable transporter
let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter {
  if (!transporter && EMAIL_USER && EMAIL_PASS) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: EMAIL_USER,
        pass: EMAIL_PASS,
      },
    });
  }
  return transporter!;
}

// ============================================================================
// SCREENSHOT FEEDBACK EMAIL NOTIFICATIONS
// ============================================================================

/**
 * Send email when new feedback is submitted
 */
export const sendFeedbackEmail = functions.firestore
  .document('feedback/{feedbackId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const feedbackId = context.params.feedbackId;

    if (!EMAIL_USER || !EMAIL_PASS) {
      console.warn('Email not configured. Skipping feedback email notification.');
      return null;
    }

    try {
      // Build email content
      const subject = `Lumina Feedback: ${data.type || 'General'} - ${data.text?.substring(0, 50) || 'No description'}`;

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #4285f4; color: white; padding: 20px; border-radius: 5px 5px 0 0; }
            .content { background: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
            .section { margin-bottom: 20px; }
            .label { font-weight: bold; color: #666; }
            .value { margin-top: 5px; }
            .attachments { list-style: none; padding: 0; }
            .attachments li { margin: 5px 0; }
            .attachments a { color: #4285f4; text-decoration: none; }
            .button { display: inline-block; padding: 10px 20px; background: #4285f4; color: white; text-decoration: none; border-radius: 5px; margin-top: 10px; }
            .device-info { background: #f5f5f5; padding: 10px; border-radius: 3px; font-family: monospace; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>📱 Lumina Feedback</h1>
            </div>
            <div class="content">
              <div class="section">
                <div class="label">Type:</div>
                <div class="value">${data.type || 'General'}</div>
              </div>

              <div class="section">
                <div class="label">User ID:</div>
                <div class="value">${data.uid || 'Anonymous'}</div>
              </div>

              <div class="section">
                <div class="label">Date:</div>
                <div class="value">${data.createdAt?.toDate?.() || new Date()}</div>
              </div>

              <div class="section">
                <div class="label">Message:</div>
                <div class="value">${data.text || 'No message provided'}</div>
              </div>

              ${data.deviceInfo ? `
                <div class="section">
                  <div class="label">Device Information:</div>
                  <div class="device-info">${JSON.stringify(data.deviceInfo, null, 2)}</div>
                </div>
              ` : ''}

              ${data.attachments && data.attachments.length > 0 ? `
                <div class="section">
                  <div class="label">Attachments (${data.attachments.length}):</div>
                  <ul class="attachments">
                    ${data.attachments.map((a: any) => `
                      <li>
                        <a href="${a.url}" target="_blank">📎 ${a.filename || 'attachment'}</a>
                      </li>
                    `).join('')}
                  </ul>
                </div>
              ` : ''}

              <div class="section">
                <a href="https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/feedback/${feedbackId}" class="button">
                  View in Firebase Console
                </a>
              </div>
            </div>
          </div>
        </body>
        </html>
      `;

      const mailOptions = {
        from: `Lumina <${EMAIL_USER}>`,
        to: ADMIN_EMAIL,
        subject: subject,
        html: htmlContent,
      };

      await getTransporter().sendMail(mailOptions);
      console.log(`Feedback email sent successfully for ${feedbackId}`);

      // Update feedback document to mark as emailed
      await snap.ref.update({
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    } catch (error) {
      console.error('Error sending feedback email:', error);
      throw error;
    }
  });

// ============================================================================
// GEOFENCE ALERT NOTIFICATIONS
// ============================================================================

/**
 * Send notifications to caregivers when geofence events occur
 */
export const sendGeofenceAlert = functions.firestore
  .document('users/{userId}/location_updates/{updateId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const userId = context.params.userId;

    // Only process geofence events
    if (!data.event || !['entered', 'exited'].includes(data.event)) {
      return null;
    }

    try {
      // Get user information
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData || !userData.caregiverIds || userData.caregiverIds.length === 0) {
        console.log('No caregivers to notify');
        return null;
      }

      const userName = userData.name || 'User';
      const zoneName = data.zoneName || 'a zone';
      const eventType = data.event === 'exited' ? 'left' : 'entered';

      // Build notification message
      const title = `🚨 Geofence Alert`;
      const body = `${userName} has ${eventType} ${zoneName}`;

      // Get all caregiver tokens
      const caregiverDocs = await Promise.all(
        userData.caregiverIds.map((id: string) =>
          admin.firestore().collection('caregivers').doc(id).get()
        )
      );

      const tokens: string[] = [];
      caregiverDocs.forEach(doc => {
        const caregiverData = doc.data();
        if (caregiverData?.fcmToken) {
          tokens.push(caregiverData.fcmToken);
        }
      });

      if (tokens.length === 0) {
        console.log('No FCM tokens found for caregivers');
        return null;
      }

      // Send push notifications
      const message = {
        notification: {
          title,
          body,
        },
        data: {
          type: 'geofence_alert',
          userId,
          event: data.event,
          zoneName,
          timestamp: data.timestamp?.toDate?.()?.toISOString() || new Date().toISOString(),
        },
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent ${response.successCount} geofence notifications, ${response.failureCount} failed`);

      return null;
    } catch (error) {
      console.error('Error sending geofence alert:', error);
      throw error;
    }
  });

// ============================================================================
// PUSH NOTIFICATION DELIVERY
// ============================================================================

/**
 * Process the notifications collection and deliver push notifications via FCM.
 * The Flutter app's NotificationService.notifyCaregivers() writes docs here
 * containing { token, title, body, data }. This function sends them.
 */
export const deliverPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const notificationId = context.params.notificationId;

    const token = data.token;
    const title = data.title;
    const body = data.body;

    if (!token || !title) {
      console.warn(`Notification ${notificationId} missing token or title, skipping`);
      return null;
    }

    try {
      await admin.messaging().send({
        token,
        notification: { title, body: body || '' },
        data: data.data || {},
      });

      // Mark as delivered
      await snap.ref.update({
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'delivered',
      });

      console.log(`Push notification ${notificationId} delivered to token ${token.substring(0, 10)}...`);
      return null;
    } catch (error: any) {
      console.error(`Error delivering notification ${notificationId}:`, error);

      // If token is invalid, mark it so and clean up
      if (
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered'
      ) {
        await snap.ref.update({
          status: 'failed',
          error: 'invalid_token',
        });
      } else {
        await snap.ref.update({
          status: 'failed',
          error: error.message || 'unknown',
        });
      }

      return null;
    }
  });

// ============================================================================
// MEDICATION REMINDER NOTIFICATIONS
// ============================================================================

/**
 * Send notifications when medication reminders are missed
 */
export const sendMedicationAlert = functions.firestore
  .document('medications/{medicationId}/logs/{logId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const medicationId = context.params.medicationId;

    // Only process missed medications
    if (data.status !== 'missed') {
      return null;
    }

    try {
      // Get medication information
      const medDoc = await admin.firestore().collection('medications').doc(medicationId).get();
      const medData = medDoc.data();

      if (!medData) {
        console.log('Medication not found');
        return null;
      }

      // Get user information
      const userDoc = await admin.firestore().collection('users').doc(medData.userId).get();
      const userData = userDoc.data();

      if (!userData || !userData.caregiverIds || userData.caregiverIds.length === 0) {
        console.log('No caregivers to notify');
        return null;
      }

      const userName = userData.name || 'User';
      const medName = medData.name || 'medication';

      // Build notification message
      const title = `💊 Missed Medication`;
      const body = `${userName} missed their ${medName}`;

      // Get all caregiver tokens
      const caregiverDocs = await Promise.all(
        userData.caregiverIds.map((id: string) =>
          admin.firestore().collection('caregivers').doc(id).get()
        )
      );

      const tokens: string[] = [];
      caregiverDocs.forEach(doc => {
        const caregiverData = doc.data();
        if (caregiverData?.fcmToken) {
          tokens.push(caregiverData.fcmToken);
        }
      });

      if (tokens.length === 0) {
        console.log('No FCM tokens found for caregivers');
        return null;
      }

      // Send push notifications
      const message = {
        notification: {
          title,
          body,
        },
        data: {
          type: 'medication_alert',
          medicationId,
          medicationName: medName,
          userId: medData.userId,
          timestamp: data.scheduledTime?.toDate?.()?.toISOString() || new Date().toISOString(),
        },
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent ${response.successCount} medication notifications, ${response.failureCount} failed`);

      return null;
    } catch (error) {
      console.error('Error sending medication alert:', error);
      throw error;
    }
  });

// ============================================================================
// ERROR REPORTING
// ============================================================================

/**
 * Send email when critical errors are reported
 */
export const sendErrorAlert = functions.firestore
  .document('errors/{errorId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const errorId = context.params.errorId;

    if (!EMAIL_USER || !EMAIL_PASS) {
      console.warn('Email not configured. Skipping error alert.');
      return null;
    }

    // Only send emails for critical errors
    const isCritical = data.level === 'critical' || data.level === 'error';
    if (!isCritical) {
      return null;
    }

    try {
      const subject = `🚨 Lumina ${data.level?.toUpperCase()} Error: ${data.message?.substring(0, 50)}`;

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #d32f2f; color: white; padding: 20px; border-radius: 5px 5px 0 0; }
            .content { background: #fff3cd; padding: 20px; border: 2px solid #d32f2f; }
            .section { margin-bottom: 20px; }
            .label { font-weight: bold; color: #666; }
            .value { margin-top: 5px; }
            .error-message { background: #f5f5f5; padding: 10px; border-left: 4px solid #d32f2f; font-family: monospace; }
            .stack-trace { background: #f5f5f5; padding: 10px; border-radius: 3px; font-family: monospace; font-size: 11px; max-height: 300px; overflow-y: auto; }
            .button { display: inline-block; padding: 10px 20px; background: #d32f2f; color: white; text-decoration: none; border-radius: 5px; margin-top: 10px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🚨 ${data.level?.toUpperCase()} Error Alert</h1>
            </div>
            <div class="content">
              <div class="section">
                <div class="label">Error Level:</div>
                <div class="value">${data.level || 'Unknown'}</div>
              </div>

              <div class="section">
                <div class="label">Error Message:</div>
                <div class="error-message">${data.message || 'No message'}</div>
              </div>

              ${data.stackTrace ? `
                <div class="section">
                  <div class="label">Stack Trace:</div>
                  <div class="stack-trace">${data.stackTrace}</div>
                </div>
              ` : ''}

              <div class="section">
                <div class="label">User ID:</div>
                <div class="value">${data.uid || 'Anonymous'}</div>
              </div>

              <div class="section">
                <div class="label">Timestamp:</div>
                <div class="value">${data.timestamp?.toDate?.() || new Date()}</div>
              </div>

              ${data.context ? `
                <div class="section">
                  <div class="label">Context:</div>
                  <div class="stack-trace">${JSON.stringify(data.context, null, 2)}</div>
                </div>
              ` : ''}

              <div class="section">
                <a href="https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/errors/${errorId}" class="button">
                  View in Firebase Console
                </a>
              </div>
            </div>
          </div>
        </body>
        </html>
      `;

      const mailOptions = {
        from: `Lumina Error Reporter <${EMAIL_USER}>`,
        to: ADMIN_EMAIL,
        subject: subject,
        html: htmlContent,
      };

      await getTransporter().sendMail(mailOptions);
      console.log(`Error alert email sent for ${errorId}`);

      return null;
    } catch (error) {
      console.error('Error sending error alert:', error);
      throw error;
    }
  });

// ============================================================================
// iOS SHARE EXTENSION - CREATE REPAIR TASK
// ============================================================================

/**
 * HTTP endpoint for iOS Share Extension to submit feedback
 * Requires API key authentication via X-API-Key header
 */
export const createRepairTaskFromShare = functions
  .runWith({
    secrets: ['VSCODE_REPAIR_API_KEY', 'ALERT_EMAIL_TO', 'SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'],
  })
  .https.onRequest(async (req, res) => {
    // CORS handling
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, X-API-Key');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    // Validate API key
    const apiKey = req.headers['x-api-key'];
    const expectedKey = process.env.VSCODE_REPAIR_API_KEY;

    if (!apiKey || apiKey !== expectedKey) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    try {
      // Parse multipart form data or JSON
      const contentType = req.headers['content-type'] || '';
      let message = '';
      let type = 'bug';
      let platform = 'ios';
      let source = 'share';
      let appName = 'Lumina';
      let ccEmail = '';
      let imageData: Buffer | null = null;

      if (contentType.includes('multipart/form-data')) {
        // Parse multipart form data
        const busboy = require('busboy');
        const bb = busboy({ headers: req.headers });

        const fields: Record<string, string> = {};
        let imageBuffer: Buffer[] = [];

        await new Promise<void>((resolve, reject) => {
          bb.on('field', (name: string, val: string) => {
            fields[name] = val;
          });

          bb.on('file', (name: string, file: any, info: any) => {
            file.on('data', (data: Buffer) => {
              imageBuffer.push(data);
            });
          });

          bb.on('finish', () => {
            message = fields.message || '';
            type = fields.type || 'bug';
            platform = fields.platform || 'ios';
            source = fields.source || 'share';
            appName = fields.appName || 'Lumina';
            ccEmail = fields.ccEmail || '';

            if (imageBuffer.length > 0) {
              imageData = Buffer.concat(imageBuffer);
            }
            resolve();
          });

          bb.on('error', reject);
          bb.end(req.rawBody);
        });
      } else {
        // Parse JSON body
        const body = req.body;
        message = body.message || '';
        type = body.type || 'bug';
        platform = body.platform || 'ios';
        source = body.source || 'share';
        appName = body.appName || 'Lumina';
        ccEmail = body.ccEmail || '';
      }

      // Create repair task document
      const taskRef = admin.firestore().collection('repair_tasks').doc();
      const taskData: Record<string, any> = {
        message,
        type,
        platform,
        source,
        appName,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (ccEmail) {
        taskData.ccEmail = ccEmail;
      }

      // Upload image to Storage if present
      if (imageData) {
        const bucket = admin.storage().bucket();
        const filename = `repair_tasks/${taskRef.id}/screenshot.jpg`;
        const file = bucket.file(filename);

        await file.save(imageData, {
          metadata: {
            contentType: 'image/jpeg',
          },
        });

        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: '03-01-2500',
        });

        taskData.imageUrl = url;
        taskData.imagePath = filename;
      }

      await taskRef.set(taskData);

      // Send email notification if SMTP is configured
      const smtpHost = process.env.SMTP_HOST;
      const smtpPort = process.env.SMTP_PORT;
      const smtpUser = process.env.SMTP_USER;
      const smtpPass = process.env.SMTP_PASS;
      const smtpFrom = process.env.SMTP_FROM;
      const alertEmailTo = process.env.ALERT_EMAIL_TO;

      if (smtpHost && smtpUser && smtpPass && alertEmailTo) {
        const transporter = nodemailer.createTransport({
          host: smtpHost,
          port: parseInt(smtpPort || '587'),
          secure: false,
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });

        const recipients = ccEmail ? `${alertEmailTo}, ${ccEmail}` : alertEmailTo;

        await transporter.sendMail({
          from: smtpFrom || smtpUser,
          to: recipients,
          subject: `[${appName}] New Feedback from iOS Share`,
          html: `
            <h2>New Feedback Received</h2>
            <p><strong>Type:</strong> ${type}</p>
            <p><strong>Platform:</strong> ${platform}</p>
            <p><strong>Source:</strong> ${source}</p>
            <p><strong>Message:</strong></p>
            <p>${message || 'No message provided'}</p>
            ${taskData.imageUrl ? `<p><strong>Screenshot:</strong> <a href="${taskData.imageUrl}">View Image</a></p>` : ''}
            <hr>
            <p><small>Task ID: ${taskRef.id}</small></p>
          `,
        });
      }

      res.status(201).json({
        success: true,
        taskId: taskRef.id,
      });
    } catch (error) {
      console.error('Error creating repair task:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

// ============================================================================
// CLEANUP OLD FEEDBACK & ERRORS
// ============================================================================

/**
 * Clean up resolved feedback and errors older than 30 days
 */
export const cleanupOldFeedback = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Clean up resolved feedback
    const feedbackQuery = admin.firestore()
      .collection('feedback')
      .where('status', '==', 'resolved')
      .where('resolvedAt', '<', thirtyDaysAgo);

    const feedbackSnapshot = await feedbackQuery.get();
    const feedbackDeletes = feedbackSnapshot.docs.map((doc) => doc.ref.delete());

    // Clean up auto-resolved errors
    const errorsQuery = admin.firestore()
      .collection('errors')
      .where('autoResolved', '==', true)
      .where('resolvedAt', '<', thirtyDaysAgo);

    const errorsSnapshot = await errorsQuery.get();
    const errorDeletes = errorsSnapshot.docs.map((doc) => doc.ref.delete());

    await Promise.all([...feedbackDeletes, ...errorDeletes]);

    console.log(`Cleaned up ${feedbackDeletes.length} feedback items and ${errorDeletes.length} errors`);
    return null;
  });

// ============================================================================
// REVENUECAT WEBHOOK
// ============================================================================

/**
 * RevenueCat webhook — receives subscription events and updates user docs.
 * Set the webhook URL in RevenueCat dashboard to:
 *   https://<region>-<project>.cloudfunctions.net/revenuecatWebhook
 * Set REVENUECAT_WEBHOOK_TOKEN in Firebase Functions config:
 *   firebase functions:config:set revenuecat.webhook_token="your-token"
 */
export const revenuecatWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  // Validate bearer token
  const authHeader = req.headers.authorization;
  const expectedToken = functions.config().revenuecat?.webhook_token;
  if (expectedToken && (!authHeader || authHeader !== `Bearer ${expectedToken}`)) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const event = req.body;
    const eventType = event.event?.type;
    const appUserId = event.event?.app_user_id; // This is the patientId

    if (!appUserId) {
      res.status(400).json({ error: 'Missing app_user_id' });
      return;
    }

    console.log(`RevenueCat event: ${eventType} for ${appUserId}`);

    const userRef = admin.firestore().collection('users').doc(appUserId);

    switch (eventType) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'UNCANCELLATION': {
        const expiresDate = event.event?.expiration_at_ms
          ? new Date(event.event.expiration_at_ms)
          : null;
        await userRef.update({
          subscriptionTier: 'premium',
          subscriptionExpiresAt: expiresDate
            ? admin.firestore.Timestamp.fromDate(expiresDate)
            : null,
          revenueCatCustomerId: event.event?.original_app_user_id || appUserId,
        });
        break;
      }
      case 'CANCELLATION':
      case 'EXPIRATION':
      case 'BILLING_ISSUE': {
        await userRef.update({
          subscriptionTier: 'free',
          subscriptionExpiresAt: null,
        });
        break;
      }
      default:
        console.log(`Unhandled RevenueCat event type: ${eventType}`);
    }

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('RevenueCat webhook error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ============================================================================
// INVITE CODE CLEANUP
// ============================================================================

/**
 * Clean up expired and unused invite codes every 6 hours
 */
export const cleanupExpiredInvites = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredQuery = admin.firestore()
      .collection('invite_codes')
      .where('isUsed', '==', false)
      .where('expiresAt', '<', now);

    const snapshot = await expiredQuery.get();

    if (snapshot.empty) {
      console.log('No expired invite codes to clean up');
      return null;
    }

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Cleaned up ${snapshot.size} expired invite codes`);
    return null;
  });

// ─── Cross-App Publisher ────────────────────────────────────

const APEX_LIFE_URL =
  'https://us-central1-apex-life-sosmartapps.cloudfunctions.net/publishCrossAppData';

/**
 * Runs daily at 11:50 PM Phoenix time.
 * Summarizes caregiving activity and publishes to Apex Life.
 *
 * Reads from:
 *   users/{userId} - Care recipients and caregivers
 *   care_tasks (or repair_tasks) - Tasks completed today
 *   medications - Medication adherence
 */
export const publishToApexLife = functions.pubsub
  .schedule('50 23 * * *')
  .timeZone('America/Phoenix')
  .onRun(async () => {
    const db = admin.firestore();
    const apiKey = functions.config().crossapp?.apex_life_key;

    if (!apiKey) {
      console.warn('crossapp.apex_life_key not set — skipping cross-app publish');
      return null;
    }

    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const startOfDay = new Date(`${today}T00:00:00`);
    const endOfDay = new Date(`${today}T23:59:59`);

    // Get user email
    let email = '';
    try {
      const usersSnap = await admin.auth().listUsers(1);
      if (usersSnap.users.length > 0) {
        email = usersSnap.users[0].email || '';
      }
    } catch {
      console.warn('Could not get user email from Firebase Auth');
    }

    if (!email) {
      console.warn('No user email found — cannot publish to Apex Life');
      return null;
    }

    // Count care recipients (users collection)
    const usersSnap = await db.collection('users').get();
    const careRecipientCount = usersSnap.size;

    // Count tasks completed today
    let tasksCompleted = 0;
    let tasksScheduled = 0;

    // Check repair_tasks (which is what Cloud Functions use)
    const tasksSnap = await db.collection('repair_tasks')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
      .get();

    tasksScheduled = tasksSnap.size;
    for (const doc of tasksSnap.docs) {
      const task = doc.data();
      if (task.status === 'completed' || task.status === 'done') {
        tasksCompleted++;
      }
    }

    // Count medication adherence
    const medsSnap = await db.collection('medications')
      .where('isActive', '==', true)
      .get();

    let totalMeds = medsSnap.size;
    let takenMeds = 0;

    for (const doc of medsSnap.docs) {
      const med = doc.data();
      // Check if today's dose was taken
      if (med.lastTaken) {
        const lastTaken = med.lastTaken.toDate
          ? med.lastTaken.toDate()
          : new Date(med.lastTaken);
        if (lastTaken >= startOfDay && lastTaken <= endOfDay) {
          takenMeds++;
        }
      }
    }

    // Prevent divide by zero
    if (totalMeds === 0) totalMeds = 1;
    const medicationAdherence = Math.round((takenMeds / totalMeds) * 100);

    // Count QuadTrack devices
    const quadtrackDevicesSnap = await db.collection('quadtrack_devices').get();
    let activeQuadTrackCount = 0;
    const offlineQuadTrackDevices: string[] = [];

    for (const doc of quadtrackDevicesSnap.docs) {
      const device = doc.data();
      if (device.status !== 'offline') {
        activeQuadTrackCount++;
      } else {
        offlineQuadTrackDevices.push(device.name || device.deviceId);
      }
    }

    const payload = {
      careRecipientCount,
      tasksCompleted,
      tasksScheduled,
      medicationAdherence,
      moodRating: undefined, // Set by the app UI, not available server-side
      incidentsToday: 0,
      caregiverStressLevel: undefined, // Set by the app UI
      activeQuadTrackDevices: activeQuadTrackCount,
      offlineQuadTrackDevices: offlineQuadTrackDevices.length > 0 ? offlineQuadTrackDevices : undefined,
    };

    const body = JSON.stringify({
      appId: 'lumina',
      email,
      date: today,
      payload,
      apiKey,
    });

    await new Promise<void>((resolve, reject) => {
      const url = new URL(APEX_LIFE_URL);
      const req = https.request(
        {
          hostname: url.hostname,
          port: 443,
          path: url.pathname,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
          },
        },
        (res) => {
          let data = '';
          res.on('data', (chunk: string) => (data += chunk));
          res.on('end', () => {
            if (res.statusCode && res.statusCode >= 400) {
              console.error(`Lumina → Apex Life publish failed (${res.statusCode}): ${data}`);
              reject(new Error(`HTTP ${res.statusCode}: ${data}`));
            } else {
              console.log(`Lumina → Apex Life published: ${data}`);
              resolve();
            }
          });
        },
      );
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    return null;
  });

// ============================================================================
// QUADTRACK LOCATION TRACKING
// ============================================================================

/**
 * Ingest location pings from QuadTrack hardware via LTE-M/MQTT bridge
 * Validates device key, stores ping, updates device status, and handles low/dead battery alerts
 */
export const ingestQuadTrackPing = functions.https.onRequest(async (req, res) => {
  // CORS handling
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Device-Key');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const deviceKey = req.headers['x-device-key'] as string;
    if (!deviceKey) {
      res.status(400).json({ error: 'Missing X-Device-Key header' });
      return;
    }

    const { lat, lng, accuracy, altitude, battery, phoneBattery, chargingState, source } = req.body;

    // Validate required fields
    if (typeof lat !== 'number' || typeof lng !== 'number' || typeof battery !== 'number') {
      res.status(400).json({ error: 'Invalid payload: lat, lng, battery are required numbers' });
      return;
    }

    const db = admin.firestore();

    // Verify device exists
    const deviceQuery = await db
      .collection('quadtrack_devices')
      .where('deviceId', '==', deviceKey)
      .limit(1)
      .get();

    if (deviceQuery.empty) {
      res.status(401).json({ error: 'Device not registered' });
      return;
    }

    const deviceDoc = deviceQuery.docs[0];
    const deviceData = deviceDoc.data();
    const deviceRef = deviceDoc.ref;

    // Store ping
    const pingRef = db.collection('quadtrack_pings').doc();
    await pingRef.set({
      deviceId: deviceKey,
      lat,
      lng,
      accuracy: accuracy || null,
      altitude: altitude || null,
      battery,
      phoneBattery: phoneBattery || null,
      chargingState: chargingState || 'on_battery',
      source: source || 'gps',
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update device doc
    const updateData: Record<string, any> = {
      lastLocation: new admin.firestore.GeoPoint(lat, lng),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      lastAccuracy: accuracy || null,
      trackerBatteryLevel: battery,
      chargingState: chargingState || 'on_battery',
      status: 'online',
    };

    if (typeof phoneBattery === 'number') {
      updateData.phoneBatteryLevel = phoneBattery;
    }

    await deviceRef.update(updateData);

    let nextPingSeconds = 60; // default

    // Determine next ping interval based on tracking mode
    if (deviceData.trackingMode === 'emergency') {
      nextPingSeconds = 10;
    } else if (deviceData.trackingMode === 'active') {
      nextPingSeconds = 30;
    } else if (deviceData.trackingMode === 'idle') {
      nextPingSeconds = 300;
    }

    // Handle low battery alert
    if (battery < 20) {
      await deviceRef.update({ status: 'low_battery' });

      // Notify caregivers
      if (deviceData.caregiverIds && deviceData.caregiverIds.length > 0) {
        const caregiverDocs = await Promise.all(
          deviceData.caregiverIds.map((id: string) =>
            db.collection('caregivers').doc(id).get()
          )
        );

        const tokens: string[] = [];
        caregiverDocs.forEach(doc => {
          const caregiverData = doc.data();
          if (caregiverData?.fcmToken) {
            tokens.push(caregiverData.fcmToken);
          }
        });

        if (tokens.length > 0) {
          const message = {
            notification: {
              title: '🔋 QuadTrack Low Battery',
              body: `${deviceData.name || 'QuadTrack'} battery is below 20%`,
            },
            data: {
              type: 'quadtrack_low_battery',
              deviceId: deviceKey,
              batteryLevel: battery.toString(),
            },
            tokens,
          };

          await admin.messaging().sendEachForMulticast(message);
        }
      }
    }

    // Handle phone dead (was charging or on battery, now 0)
    const prevPhoneBattery = deviceData.phoneBatteryLevel ?? -1;
    if (typeof phoneBattery === 'number' && phoneBattery === 0 && prevPhoneBattery > 0) {
      await deviceRef.update({
        status: 'phone_dead',
        trackingMode: 'emergency',
      });

      // Send URGENT notification to caregivers
      if (deviceData.caregiverIds && deviceData.caregiverIds.length > 0) {
        const caregiverDocs = await Promise.all(
          deviceData.caregiverIds.map((id: string) =>
            db.collection('caregivers').doc(id).get()
          )
        );

        const tokens: string[] = [];
        caregiverDocs.forEach(doc => {
          const caregiverData = doc.data();
          if (caregiverData?.fcmToken) {
            tokens.push(caregiverData.fcmToken);
          }
        });

        if (tokens.length > 0) {
          const message = {
            notification: {
              title: '🚨 URGENT: Phone Dead',
              body: `${deviceData.name || 'Patient'}'s phone battery is dead. Tracking mode switched to emergency.`,
            },
            data: {
              type: 'quadtrack_phone_dead',
              deviceId: deviceKey,
              timestamp: new Date().toISOString(),
            },
            tokens,
          };

          await admin.messaging().sendEachForMulticast(message);
        }
      }
    }

    res.status(200).json({
      success: true,
      nextPingSeconds,
    });
  } catch (error) {
    console.error('Error ingesting QuadTrack ping:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Evaluate geofences for QuadTrack devices
 * Triggers on new quadtrack_pings — checks if device is inside danger zones or outside safe zones
 */
export const evaluateQuadTrackGeofences = functions.firestore
  .document('quadtrack_pings/{pingId}')
  .onCreate(async (snap, context) => {
    const ping = snap.data();
    const db = admin.firestore();

    try {
      // Get device
      const deviceQuery = await db
        .collection('quadtrack_devices')
        .where('deviceId', '==', ping.deviceId)
        .limit(1)
        .get();

      if (deviceQuery.empty) {
        console.log('Device not found for ping');
        return null;
      }

      const deviceDoc = deviceQuery.docs[0];
      const deviceData = deviceDoc.data();

      if (!deviceData.patientId) {
        return null;
      }

      // Get all active geo zones for this patient
      const zonesSnap = await db
        .collection('users')
        .doc(deviceData.patientId)
        .collection('geo_zones')
        .where('isActive', '==', true)
        .get();

      if (zonesSnap.empty) {
        return null;
      }

      const pingLat = ping.lat;
      const pingLng = ping.lng;

      // Haversine distance calculation
      const haversineDistance = (lat1: number, lng1: number, lat2: number, lng2: number): number => {
        const R = 6371; // Earth radius in km
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLng = ((lng2 - lng1) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
      };

      // Check each zone
      for (const zoneDoc of zonesSnap.docs) {
        const zone = zoneDoc.data();
        const distance = haversineDistance(pingLat, pingLng, zone.lat, zone.lng);
        const isInside = distance <= (zone.radiusKm || 0.5);

        // Determine if we should trigger an event
        let eventType: string | null = null;

        if (zone.type === 'safe' || zone.type === 'home') {
          // Outside safe/home zone = alert
          if (!isInside) {
            eventType = 'left_safe_zone';
          }
        } else if (zone.type === 'danger') {
          // Inside danger zone = alert
          if (isInside) {
            eventType = 'entered_danger_zone';
          }
        }

        if (eventType) {
          // Write to geo_zone_events
          const eventRef = db.collection('geo_zone_events').doc();
          await eventRef.set({
            deviceId: ping.deviceId,
            patientId: deviceData.patientId,
            zoneId: zoneDoc.id,
            zoneName: zone.name,
            zoneType: zone.type,
            eventType,
            lat: pingLat,
            lng: pingLng,
            distance,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Send notifications to caregivers
          if (deviceData.caregiverIds && deviceData.caregiverIds.length > 0) {
            const caregiverDocs = await Promise.all(
              deviceData.caregiverIds.map((id: string) =>
                db.collection('caregivers').doc(id).get()
              )
            );

            const tokens: string[] = [];
            caregiverDocs.forEach(doc => {
              const caregiverData = doc.data();
              if (caregiverData?.fcmToken) {
                tokens.push(caregiverData.fcmToken);
              }
            });

            if (tokens.length > 0) {
              const title =
                eventType === 'left_safe_zone'
                  ? '⚠️ Left Safe Zone'
                  : '🚨 Entered Danger Zone';
              const body =
                eventType === 'left_safe_zone'
                  ? `${deviceData.name || 'Patient'} has left ${zone.name}`
                  : `${deviceData.name || 'Patient'} has entered ${zone.name}`;

              const message = {
                notification: { title, body },
                data: {
                  type: 'geofence_alert',
                  deviceId: ping.deviceId,
                  eventType,
                  zoneName: zone.name,
                  distance: distance.toString(),
                },
                tokens,
              };

              await admin.messaging().sendEachForMulticast(message);
            }
          }
        }
      }

      return null;
    } catch (error) {
      console.error('Error evaluating QuadTrack geofences:', error);
      throw error;
    }
  });

/**
 * Health check — marks devices as offline if they haven't pinged recently
 * Runs every 15 minutes
 */
export const quadTrackHealthCheck = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const db = admin.firestore();

    try {
      // Get all active devices
      const devicesSnap = await db
        .collection('quadtrack_devices')
        .where('status', '!=', 'offline')
        .get();

      if (devicesSnap.empty) {
        console.log('No active QuadTrack devices to check');
        return null;
      }

      const now = new Date();

      for (const deviceDoc of devicesSnap.docs) {
        const device = deviceDoc.data();

        if (!device.lastSeenAt) {
          continue;
        }

        const lastSeen = device.lastSeenAt.toDate
          ? device.lastSeenAt.toDate()
          : new Date(device.lastSeenAt);
        const secondsAgo = (now.getTime() - lastSeen.getTime()) / 1000;

        // Determine expected interval based on tracking mode
        let expectedIntervalSeconds = 60;
        if (device.trackingMode === 'emergency') {
          expectedIntervalSeconds = 10;
        } else if (device.trackingMode === 'active') {
          expectedIntervalSeconds = 30;
        } else if (device.trackingMode === 'idle') {
          expectedIntervalSeconds = 300;
        }

        const timeoutThreshold = expectedIntervalSeconds * 2;

        // If exceeded 2x expected interval, mark offline
        if (secondsAgo > timeoutThreshold) {
          await deviceDoc.ref.update({ status: 'offline' });

          // Notify caregivers
          if (device.caregiverIds && device.caregiverIds.length > 0) {
            const caregiverDocs = await Promise.all(
              device.caregiverIds.map((id: string) =>
                db.collection('caregivers').doc(id).get()
              )
            );

            const tokens: string[] = [];
            caregiverDocs.forEach(doc => {
              const caregiverData = doc.data();
              if (caregiverData?.fcmToken) {
                tokens.push(caregiverData.fcmToken);
              }
            });

            if (tokens.length > 0) {
              const message = {
                notification: {
                  title: '📡 Device Offline',
                  body: `QuadTrack for ${device.name || 'Patient'} has gone offline`,
                },
                data: {
                  type: 'quadtrack_offline',
                  deviceId: device.deviceId,
                  timestamp: now.toISOString(),
                },
                tokens,
              };

              await admin.messaging().sendEachForMulticast(message);
            }
          }
        }
      }

      console.log(`QuadTrack health check completed for ${devicesSnap.size} devices`);
      return null;
    } catch (error) {
      console.error('Error in QuadTrack health check:', error);
      throw error;
    }
  });

/**
 * Retrieve pending commands for QuadTrack devices
 * Device polls this endpoint to fetch commands and execute them
 */
export const quadTrackCommand = functions.https.onRequest(async (req, res) => {
  // CORS handling
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const deviceId = req.query.deviceId as string;
    if (!deviceId) {
      res.status(400).json({ error: 'Missing deviceId query parameter' });
      return;
    }

    const db = admin.firestore();

    // Check for pending commands
    const commandRef = db.collection('quadtrack_commands').doc(deviceId);
    const commandDoc = await commandRef.get();

    if (!commandDoc.exists) {
      res.status(200).json({ command: null });
      return;
    }

    const command = commandDoc.data();

    // Delete command after retrieval
    await commandRef.delete();

    res.status(200).json({ command });
  } catch (error) {
    console.error('Error fetching QuadTrack command:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Receive and process Bouncie vehicle tracking alerts
 * Called from geofence_service when vehicle location sync issues are detected
 * Stores alert events and notifies caregivers
 */
export const bouncieWebhook = functions.https.onRequest(async (req, res) => {
  // CORS handling
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const {
      deviceId,
      userId,
      alertType,
      title,
      body,
      distanceMeters,
      vehicleLat,
      vehicleLng,
      phoneLat,
      phoneLng,
    } = req.body;

    if (!userId || !alertType) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const db = admin.firestore();

    // Store alert event
    const alertRef = db.collection('bouncie_alerts').doc();
    await alertRef.set({
      deviceId: deviceId || null,
      userId,
      alertType,
      title,
      body,
      distanceMeters: distanceMeters || null,
      vehicleLocation: vehicleLat && vehicleLng
        ? new admin.firestore.GeoPoint(vehicleLat, vehicleLng)
        : null,
      phoneLocation: phoneLat && phoneLng
        ? new admin.firestore.GeoPoint(phoneLat, phoneLng)
        : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });

    // Notify caregivers
    try {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await userRef.get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        const caregiverIds = userData?.caregiverIds || [];

        for (const caregiverId of caregiverIds) {
          const notifRef = db.collection('notifications').doc();
          await notifRef.set({
            caregiverId,
            userId,
            title: title || 'Vehicle Tracking Alert',
            body: body || `Bouncie alert: ${alertType}`,
            data: {
              type: 'bouncie_alert',
              alertType,
              distanceMeters: distanceMeters || null,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            delivered: false,
          });
        }
      }
    } catch (notifyError) {
      console.warn('Error notifying caregivers of Bouncie alert:', notifyError);
      // Don't fail the request if notification fails
    }

    res.status(200).json({ success: true, alertId: alertRef.id });
  } catch (error) {
    console.error('Error processing Bouncie webhook:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
