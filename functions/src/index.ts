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
        // App stores tokens in the fcmTokens ARRAY (legacy singular
        // fcmToken kept as fallback)
        if (caregiverData?.fcmTokens?.length) {
          tokens.push(...caregiverData.fcmTokens);
        } else if (caregiverData?.fcmToken) {
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
        // App stores tokens in the fcmTokens ARRAY (legacy singular
        // fcmToken kept as fallback)
        if (caregiverData?.fcmTokens?.length) {
          tokens.push(...caregiverData.fcmTokens);
        } else if (caregiverData?.fcmToken) {
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
 * Expected ping interval in seconds, derived from the device's tracking
 * mode. MUST stay in sync with the Dart TrackingMode enum
 * (lib/core/models/quadtrack_device.dart): normal=30min, emergency=5min
 * (overridden by battery-aware emergencyIntervalMinutes), idle=240min.
 */
const quadTrackIntervalSeconds = (device: Record<string, any>): number => {
  if (device.trackingMode === 'emergency') {
    return (device.emergencyIntervalMinutes || 5) * 60;
  }
  if (device.trackingMode === 'idle') {
    return 240 * 60;
  }
  return 30 * 60; // normal
};

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

    // Store ping — canonical shape matches the Dart QuadTrackPing model
    // (location GeoPoint + batteryLevel + timestamp) and keys deviceId by
    // the DEVICE DOC ID, which is what the app streams pings by
    // (streamLatestPings(device.id)). receivedAt kept as server metadata.
    const pingRef = db.collection('quadtrack_pings').doc();
    await pingRef.set({
      deviceId: deviceDoc.id,
      hardwareSerial: deviceKey,
      location: new admin.firestore.GeoPoint(lat, lng),
      accuracy: accuracy ?? null,
      altitude: altitude ?? null,
      batteryLevel: battery,
      // NOTE: must be ?? (not ||) — phoneBattery 0 means DEAD, not absent
      phoneBatteryLevel: typeof phoneBattery === 'number' ? phoneBattery : null,
      chargingState: chargingState || 'on_battery',
      source: source || 'gps',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
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

    // Next ping interval derived from the device's actual mode/interval
    // (same semantics as the Dart TrackingMode enum)
    const nextPingSeconds = quadTrackIntervalSeconds(deviceData);

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
          // App stores tokens in the fcmTokens ARRAY (legacy singular
          // fcmToken kept as fallback)
          if (caregiverData?.fcmTokens?.length) {
            tokens.push(...caregiverData.fcmTokens);
          } else if (caregiverData?.fcmToken) {
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
              deviceId: deviceDoc.id,
              batteryLevel: battery.toString(),
              payload: `quadtrack:${deviceDoc.id}`,
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
          // App stores tokens in the fcmTokens ARRAY (legacy singular
          // fcmToken kept as fallback)
          if (caregiverData?.fcmTokens?.length) {
            tokens.push(...caregiverData.fcmTokens);
          } else if (caregiverData?.fcmToken) {
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
              deviceId: deviceDoc.id,
              timestamp: new Date().toISOString(),
              payload: `quadtrack:${deviceDoc.id}`,
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
      // Get device — ping.deviceId is canonically the device DOC ID;
      // fall back to hardware-serial lookup for any legacy pings.
      let deviceData: Record<string, any> | undefined;
      const deviceByDocId = await db
        .collection('quadtrack_devices')
        .doc(ping.deviceId)
        .get();

      if (deviceByDocId.exists) {
        deviceData = deviceByDocId.data();
      } else {
        const deviceQuery = await db
          .collection('quadtrack_devices')
          .where('deviceId', '==', ping.deviceId)
          .limit(1)
          .get();
        if (!deviceQuery.empty) {
          deviceData = deviceQuery.docs[0].data();
        }
      }

      if (!deviceData) {
        console.log('Device not found for ping');
        return null;
      }

      if (!deviceData.patientId) {
        return null;
      }

      // Get all active geo zones for this patient — zones live in the
      // TOP-LEVEL geo_zones collection keyed by userId (the app writes
      // them there; the old users/{id}/geo_zones subcollection path
      // never matched anything).
      const zonesSnap = await db
        .collection('geo_zones')
        .where('userId', '==', deviceData.patientId)
        .where('isActive', '==', true)
        .get();

      if (zonesSnap.empty) {
        return null;
      }

      const pingLat = ping.location?.latitude || ping.lat;
      const pingLng = ping.location?.longitude || ping.lng;

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

      // Check each zone — GeoZone stores center (GeoPoint) and
      // radiusMeters (haversine here returns km)
      for (const zoneDoc of zonesSnap.docs) {
        const zone = zoneDoc.data();
        const zoneLat = zone.center?.latitude || zone.lat;
        const zoneLng = zone.center?.longitude || zone.lng;
        const distance = haversineDistance(pingLat, pingLng, zoneLat, zoneLng);
        const radiusKm = (zone.radiusMeters || 100) / 1000;
        const isInside = distance <= radiusKm;

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
              // App stores tokens in the fcmTokens ARRAY (legacy singular
              // fcmToken kept as fallback)
              if (caregiverData?.fcmTokens?.length) {
                tokens.push(...caregiverData.fcmTokens);
              } else if (caregiverData?.fcmToken) {
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
                  payload: `quadtrack:${ping.deviceId}`,
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

        // Expected interval from the device's actual mode (minutes-based,
        // same semantics as the app). Threshold = 2x expected, floored at
        // 10 minutes — this job only runs every 15 minutes, so sub-minute
        // thresholds would just flap fast-pinging emergency devices.
        const expectedIntervalSeconds = quadTrackIntervalSeconds(device);
        const timeoutThreshold = Math.max(expectedIntervalSeconds * 2, 600);

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
              // App stores tokens in the fcmTokens ARRAY (legacy singular
              // fcmToken kept as fallback)
              if (caregiverData?.fcmTokens?.length) {
                tokens.push(...caregiverData.fcmTokens);
              } else if (caregiverData?.fcmToken) {
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
                  deviceId: deviceDoc.id,
                  timestamp: now.toISOString(),
                  payload: `quadtrack:${deviceDoc.id}`,
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
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Device-Key');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Authenticate the device by hardware key (same scheme as ingest) —
    // previously this endpoint was unauthenticated and anyone could
    // consume pending commands.
    const deviceKey = req.headers['x-device-key'] as string;
    if (!deviceKey) {
      res.status(400).json({ error: 'Missing X-Device-Key header' });
      return;
    }

    const db = admin.firestore();

    const deviceQuery = await db
      .collection('quadtrack_devices')
      .where('deviceId', '==', deviceKey)
      .limit(1)
      .get();

    if (deviceQuery.empty) {
      res.status(401).json({ error: 'Device not registered' });
      return;
    }

    // Commands are keyed by the DEVICE DOC ID (that's where the app
    // writes them) — resolve it from the authenticated device.
    const commandRef = db
      .collection('quadtrack_commands')
      .doc(deviceQuery.docs[0].id);
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

// ============================================================================
// TRIP ANALYSIS & CAREGIVER ALERTS (Bouncie)
// ============================================================================
//
// Runs every 4 hours: for each per-family Bouncie connection, fetches the
// last ~25h of trips, evaluates the SAME heuristics as the app's
// lib/features/bouncie/trip_analyzer.dart (keep thresholds in sync), and
// notifies caregivers of NEW concerns via FCM push — and via SMS when
// Twilio secrets are configured (set to empty strings to disable SMS).
//
// Secrets required before deploy (firebase functions:secrets:set):
//   BOUNCIE_FN_CLIENT_ID, BOUNCIE_FN_CLIENT_SECRET, BOUNCIE_FN_REDIRECT_URI
//   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER  (may be empty)

const NIGHT_START = 22;
const NIGHT_END = 5;
const HARSH_EVENTS_ALERT = 3;
const SPEED_WARN = 80;
const SPEED_ALERT = 90;
const LONG_TRIP_MIN = 90;

interface TripConcernTS {
  severity: 'warning' | 'alert';
  title: string;
  detail: string;
  key: string; // dedupe key: `${title}|${tripStartTime}`
}

function analyzeTripsTS(trips: any[]): TripConcernTS[] {
  const concerns: TripConcernTS[] = [];
  for (const trip of trips) {
    const startRaw: string | undefined = trip.startTime;
    const start = startRaw ? new Date(startRaw) : null;
    const end = trip.endTime ? new Date(trip.endTime) : null;
    const maxSpeed: number = trip.maxSpeed ?? 0;
    const harsh: number =
      (trip.hardBrakingCount ?? trip.hardBrakes ?? 0) +
      (trip.hardAccelerationCount ?? trip.hardAccelerations ?? 0);
    const whenKey = startRaw ?? 'unknown';
    // Format in the vehicle's local-ish time; server runs UTC so show UTC-7
    // (AZ, no DST) — good enough for alert text.
    const when = start
      ? new Date(start.getTime() - 7 * 3600 * 1000)
          .toISOString()
          .slice(5, 16)
          .replace('T', ' ')
      : 'a recent trip';

    if (start) {
      const azHour = (start.getUTCHours() - 7 + 24) % 24;
      if (azHour >= NIGHT_START || azHour < NIGHT_END) {
        concerns.push({
          severity: 'alert',
          title: 'Night driving',
          detail: `Trip started at ${when} — driving late at night.`,
          key: `Night driving|${whenKey}`,
        });
      }
    }
    if (harsh >= HARSH_EVENTS_ALERT) {
      concerns.push({
        severity: 'alert',
        title: 'Harsh driving',
        detail: `${harsh} hard braking/acceleration events on the trip at ${when}.`,
        key: `Harsh driving|${whenKey}`,
      });
    }
    if (maxSpeed >= SPEED_ALERT) {
      concerns.push({
        severity: 'alert',
        title: 'High speed',
        detail: `Reached ${Math.round(maxSpeed)} mph on the trip at ${when}.`,
        key: `High speed|${whenKey}`,
      });
    } else if (maxSpeed >= SPEED_WARN) {
      concerns.push({
        severity: 'warning',
        title: 'Elevated speed',
        detail: `Reached ${Math.round(maxSpeed)} mph on the trip at ${when}.`,
        key: `Elevated speed|${whenKey}`,
      });
    }
    if (start && end) {
      const minutes = (end.getTime() - start.getTime()) / 60000;
      if (minutes >= LONG_TRIP_MIN) {
        concerns.push({
          severity: 'warning',
          title: 'Long trip',
          detail: `The trip at ${when} lasted ${Math.floor(minutes / 60)}h ${Math.round(minutes % 60)}m.`,
          key: `Long trip|${whenKey}`,
        });
      }
    }
  }
  return concerns;
}

async function sendTwilioSms(
  sid: string,
  token: string,
  from: string,
  to: string,
  body: string,
): Promise<void> {
  const params = new URLSearchParams({ From: from, To: to, Body: body });
  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization:
          'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    },
  );
  if (!res.ok) {
    console.error(`Twilio SMS to ${to} failed: ${res.status} ${await res.text()}`);
  }
}

export const analyzeTripsAndAlert = functions
  .runWith({
    secrets: [
      'BOUNCIE_FN_CLIENT_ID',
      'BOUNCIE_FN_CLIENT_SECRET',
      'BOUNCIE_FN_REDIRECT_URI',
      'TWILIO_ACCOUNT_SID',
      'TWILIO_AUTH_TOKEN',
      'TWILIO_FROM_NUMBER',
    ],
    timeoutSeconds: 300,
  })
  .pubsub.schedule('every 4 hours')
  .onRun(async () => {
    const clientId = (process.env.BOUNCIE_FN_CLIENT_ID || '').trim();
    const clientSecret = (process.env.BOUNCIE_FN_CLIENT_SECRET || '').trim();
    const redirectUri = (process.env.BOUNCIE_FN_REDIRECT_URI || '').trim();
    const twilioSid = (process.env.TWILIO_ACCOUNT_SID || '').trim();
    const twilioToken = (process.env.TWILIO_AUTH_TOKEN || '').trim();
    const twilioFrom = (process.env.TWILIO_FROM_NUMBER || '').trim();
    const smsEnabled = !!(twilioSid && twilioToken && twilioFrom);

    if (!clientId || !clientSecret) {
      console.log('Bouncie function secrets not configured; skipping.');
      return null;
    }

    const db = admin.firestore();
    const connections = await db.collection('bouncie_connections').get();
    console.log(
      `Trip analysis: ${connections.size} connection(s), SMS ${smsEnabled ? 'ENABLED' : 'disabled'}`,
    );

    for (const connDoc of connections.docs) {
      const patientId = connDoc.id;
      const conn = connDoc.data();
      try {
        // Exchange the family's auth code for a token.
        const tokenRes = await fetch('https://auth.bouncie.com/oauth/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: clientId,
            client_secret: clientSecret,
            grant_type: 'authorization_code',
            code: conn.authCode,
            redirect_uri: redirectUri,
          }),
        });
        if (!tokenRes.ok) {
          console.error(
            `Bouncie token exchange failed for ${patientId}: ${tokenRes.status}`,
          );
          continue;
        }
        const accessToken = (await tokenRes.json()).access_token as string;

        // Last 25 hours of trips (overlap so nothing slips between runs).
        const now = new Date();
        const windowStart = new Date(now.getTime() - 25 * 3600 * 1000);
        const tripsRes = await fetch(
          `https://api.bouncie.dev/v1/trips?imei=${conn.imei}&gps-format=polyline` +
            `&starts-after=${windowStart.toISOString()}&ends-before=${now.toISOString()}`,
          { headers: { Authorization: accessToken } },
        );
        if (!tripsRes.ok) {
          console.error(`Trips fetch failed for ${patientId}: ${tripsRes.status}`);
          continue;
        }
        const trips = (await tripsRes.json()) as any[];
        const concerns = analyzeTripsTS(trips);
        if (concerns.length === 0) continue;

        // Dedupe against already-alerted concerns.
        const stateRef = db.collection('trip_alerts').doc(patientId);
        const stateDoc = await stateRef.get();
        const alerted: string[] = stateDoc.data()?.alertedKeys ?? [];
        const fresh = concerns.filter((c) => !alerted.includes(c.key));
        if (fresh.length === 0) continue;

        // Gather patient + caregivers.
        const userDoc = await db.collection('users').doc(patientId).get();
        const userData = userDoc.data();
        const patientName = userData?.name ?? 'your family member';
        const caregiverIds: string[] = userData?.caregiverIds ?? [];
        const caregiverDocs = await Promise.all(
          caregiverIds.map((id) => db.collection('caregivers').doc(id).get()),
        );

        const worst = fresh.some((c) => c.severity === 'alert')
          ? 'alert'
          : 'warning';
        const title =
          worst === 'alert' ? '🚗 Driving alert' : '🚗 Driving notice';
        const summary = fresh
          .slice(0, 3)
          .map((c) => `${c.title}: ${c.detail}`)
          .join(' ');
        const body = `${patientName} — ${summary}`;

        // Push notifications.
        const tokens: string[] = [];
        const phones: string[] = [];
        for (const doc of caregiverDocs) {
          const cg = doc.data();
          if (cg?.fcmTokens?.length) tokens.push(...cg.fcmTokens);
          else if (cg?.fcmToken) tokens.push(cg.fcmToken);
          if (cg?.phoneNumber) phones.push(cg.phoneNumber);
        }
        if (tokens.length > 0) {
          const response = await admin.messaging().sendEachForMulticast({
            notification: { title, body },
            data: { type: 'trip_alert', userId: patientId },
            tokens,
          });
          console.log(
            `Trip alert push for ${patientId}: ${response.successCount} ok, ${response.failureCount} failed`,
          );
        }

        // SMS via Twilio (when configured).
        if (smsEnabled) {
          for (const phone of phones) {
            const to = phone.startsWith('+')
              ? phone
              : `+1${phone.replace(/\D/g, '')}`;
            await sendTwilioSms(
              twilioSid,
              twilioToken,
              twilioFrom,
              to,
              `Lumina: ${title.replace('🚗 ', '')} — ${body}`,
            );
          }
          console.log(`Trip alert SMS sent to ${phones.length} caregiver(s)`);
        }

        // Persist dedupe state (cap growth).
        const merged = [...alerted, ...fresh.map((c) => c.key)].slice(-200);
        await stateRef.set(
          {
            alertedKeys: merged,
            lastAlertAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSummary: body,
          },
          { merge: true },
        );
      } catch (e) {
        console.error(`Trip analysis failed for ${patientId}:`, e);
      }
    }
    return null;
  });

// ============================================================================
// AI PHOTO VERIFICATION OF TASK COMPLETION (2026-07-12)
// Patient photographs the completed task (empty pill compartment, filled
// pet bowl…); Claude vision confirms; caregivers are alerted on failed
// verification or when a photo-required task is missed entirely.
// ============================================================================

/** Sync the verdict onto the newest task_completions history entry. */
async function updateCompletionLog(
  reminderId: string,
  status: string,
  reason: string | null,
): Promise<void> {
  try {
    const db = admin.firestore();
    const snap = await db
      .collection('task_completions')
      .where('reminderId', '==', reminderId)
      .orderBy('completedAt', 'desc')
      .limit(1)
      .get();
    if (!snap.empty) {
      await snap.docs[0].ref.update({
        verificationStatus: status,
        verificationReason: reason,
      });
    }
  } catch (e) {
    console.error('updateCompletionLog failed:', e);
  }
}

/** Push a notification to every caregiver of a patient (fcmTokens arrays). */
async function notifyCaregiversAboutTask(
  userId: string,
  title: string,
  body: string,
  reminderId: string,
): Promise<void> {
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  if (!userData?.caregiverIds?.length) {
    console.log('notifyCaregiversAboutTask: no caregivers');
    return;
  }
  const caregiverDocs = await Promise.all(
    userData.caregiverIds.map((id: string) =>
      db.collection('caregivers').doc(id).get(),
    ),
  );
  const tokens: string[] = [];
  caregiverDocs.forEach((doc) => {
    const c = doc.data();
    if (c?.fcmTokens?.length) tokens.push(...c.fcmTokens);
    else if (c?.fcmToken) tokens.push(c.fcmToken);
  });
  if (!tokens.length) {
    console.log('notifyCaregiversAboutTask: no FCM tokens');
    return;
  }
  const response = await admin.messaging().sendEachForMulticast({
    notification: { title, body },
    data: {
      type: 'task_alert',
      reminderId,
      userId,
      timestamp: new Date().toISOString(),
    },
    tokens,
  });
  console.log(
    `task alert: ${response.successCount} sent, ${response.failureCount} failed`,
  );
}

/**
 * When a completion photo is attached to a reminder, ask Claude vision
 * whether the photo actually shows the task done, and record the verdict.
 * Failed verification alerts caregivers immediately.
 */
export const verifyTaskCompletionPhoto = functions
  .runWith({ secrets: ['ANTHROPIC_API_KEY'], timeoutSeconds: 60 })
  .firestore.document('reminders/{reminderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Only when a completion photo is NEWLY attached
    if (
      !after.completionPhotoUrl ||
      after.completionPhotoUrl === before.completionPhotoUrl
    ) {
      return null;
    }
    // Already verified ON DEVICE by hash match against the reference —
    // no AI needed (cost-first design, 2026-07-12).
    if (after.verificationStatus === 'verified') {
      console.log('verifyTaskCompletionPhoto: matched locally, skipping AI');
      // Caregivers get GOOD news too, not just failures (2026-07-13)
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(after.userId)
        .get();
      const userName = userDoc.data()?.name || 'Your loved one';
      await notifyCaregiversAboutTask(
        after.userId,
        '✅ Task completed',
        `${userName} completed "${after.title}" — photo matched previous ` +
          'verified photo',
        context.params.reminderId,
      );
      return null;
    }

    const reminderId = context.params.reminderId;
    const db = admin.firestore();
    const apiKey = (process.env.ANTHROPIC_API_KEY || '').trim();
    if (!apiKey) {
      console.log('ANTHROPIC_API_KEY not configured; leaving unverified.');
      return null;
    }

    try {
      // Wire values from ReminderType (reminder.dart)
      // Phoenix local weekday so Claude checks the right pillbox slot
      const phxDay = new Date(Date.now() - 7 * 3600 * 1000).toLocaleDateString(
        'en-US',
        { weekday: 'long', timeZone: 'UTC' },
      );
      const expectations: Record<string, string> = {
        medication:
          `Today is ${phxDay}. Weekly pill organizers are laid out ` +
          'S M T W T F S, normally LEFT to RIGHT starting with Sunday. ' +
          'There may be TWO organizers (morning and evening doses) — ' +
          'check today\'s compartment in each. Work step by step: ' +
          `(1) locate the compartment labeled for ${phxDay}, reading the ` +
          'printed letters, (2) look inside ONLY that compartment. ' +
          'The dose was TAKEN if today\'s compartment is empty — an ' +
          'open or partially open lid with nothing inside also means ' +
          'taken. Other days\' compartments may still be full; ignore ' +
          'them completely. Only answer verified=false if you can ' +
          'CLEARLY see pills remaining inside today\'s compartment.',
        pet_care:
          'The photo should show pet food and/or water present in the ' +
          'pet bowls — meaning the pet was fed.',
        meal_time:
          'The photo should show evidence a meal happened (prepared food, ' +
          'or an empty/finished plate).',
        hydration:
          'The photo should show evidence of drinking (a glass or bottle ' +
          'that is empty or being used).',
      };
      const expectation =
        expectations[after.type] ||
        'The photo should show clear evidence the task was completed.';

      const promptText =
        'You verify care-task completion photos for a ' +
        `dementia-care app. Task: "${after.title}" ` +
        `(type: ${after.type}). ${expectation}\n\n` +
        'Be lenient — these photos are taken by elderly ' +
        'users; poor framing or blur is fine as long as the ' +
        'evidence is visible. Does this photo show the task ' +
        'was completed? Respond with ONLY JSON: ' +
        '{"verified": true|false, "reason": "<one short ' +
        'sentence in plain language>"}';

      const askModel = async (
        model: string,
      ): Promise<{ verified?: boolean; reason?: string }> => {
        const res = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: JSON.stringify({
            model,
            max_tokens: 300,
            messages: [
              {
                role: 'user',
                content: [
                  {
                    type: 'image',
                    source: { type: 'url', url: after.completionPhotoUrl },
                  },
                  { type: 'text', text: promptText },
                ],
              },
            ],
          }),
        });
        if (!res.ok) {
          throw new Error(`Anthropic API ${res.status}: ${await res.text()}`);
        }
        const out = (await res.json()) as {
          content?: Array<{ text?: string }>;
        };
        const text = out?.content?.[0]?.text || '';
        const match = text.match(/\{[\s\S]*\}/);
        return match
          ? JSON.parse(match[0])
          : { verified: false, reason: 'Unreadable verification response' };
      };

      // Cheap first pass; a FAILED verdict gets one second opinion from
      // a stronger model before we alarm the caregiver — false alarms
      // cost more trust than the ~1¢ escalation (2026-07-12: Haiku
      // misread a pill organizer's Sunday slot as full).
      let verdict = await askModel('claude-haiku-4-5-20251001');
      if (!verdict.verified) {
        console.log(
          `Haiku said failed (${verdict.reason}); escalating to Sonnet`,
        );
        verdict = await askModel('claude-sonnet-5');
      }

      const update: Record<string, unknown> = {
        verificationStatus: verdict.verified ? 'verified' : 'failed',
        verificationReason: verdict.reason || null,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      // Learn the reference: this AI-verified photo's hash becomes the
      // "known good" that future photos are matched against ON DEVICE,
      // so subsequent days verify for free.
      if (verdict.verified && after.completionPhotoHash) {
        update.referencePhotoHash = after.completionPhotoHash;
      }
      await db.collection('reminders').doc(reminderId).update(update);
      await updateCompletionLog(
        reminderId,
        verdict.verified ? 'verified' : 'failed',
        verdict.reason || null,
      );

      const userDoc = await db.collection('users').doc(after.userId).get();
      const userName = userDoc.data()?.name || 'Your loved one';
      if (!verdict.verified) {
        await notifyCaregiversAboutTask(
          after.userId,
          '⚠️ Task photo needs a look',
          `${userName} marked "${after.title}" done, but the photo ` +
            `didn't confirm it: ${verdict.reason || 'no evidence visible'}`,
          reminderId,
        );
      } else {
        // Confirmation on success too (2026-07-13)
        await notifyCaregiversAboutTask(
          after.userId,
          '✅ Task completed',
          `${userName} completed "${after.title}" — ` +
            `${verdict.reason || 'photo verified'}`,
          reminderId,
        );
      }
      return null;
    } catch (e) {
      console.error('verifyTaskCompletionPhoto error:', e);
      // Record the error but never block completion on AI availability
      await db.collection('reminders').doc(reminderId).update({
        verificationStatus: 'error',
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }
  });

/**
 * Every 30 min: find photo-required reminders that are past due (45 min
 * grace) with NO completion today, and alert caregivers once per day.
 * Phoenix is UTC-7 year-round (no DST), so local time is a fixed offset.
 */
export const sweepMissedPhotoTasks = functions
  .runWith({ timeoutSeconds: 120 })
  .pubsub.schedule('every 30 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const PHX_OFFSET_MS = 7 * 3600 * 1000; // America/Phoenix, no DST
    const GRACE_MS = 45 * 60 * 1000;
    const now = new Date();
    const phxNow = new Date(now.getTime() - PHX_OFFSET_MS);
    // Phoenix midnight expressed as a real UTC instant
    const phxMidnightUtc = new Date(
      Date.UTC(
        phxNow.getUTCFullYear(),
        phxNow.getUTCMonth(),
        phxNow.getUTCDate(),
      ).valueOf() + PHX_OFFSET_MS,
    );
    const phxWeekday = ((phxNow.getUTCDay() + 6) % 7) + 1; // 1=Mon…7=Sun

    // Two equality filters — no composite index required.
    const snap = await db
      .collection('reminders')
      .where('requiresPhoto', '==', true)
      .where('isActive', '==', true)
      .get();

    let alerted = 0;
    for (const doc of snap.docs) {
      const r = doc.data();
      try {
        const sched = r.scheduledTime?.toDate?.();
        if (!sched) continue;
        const schedPhx = new Date(sched.getTime() - PHX_OFFSET_MS);

        // Is this reminder scheduled for today (Phoenix)?
        const freq = r.repeatFrequency || 'daily';
        if (freq === 'once') {
          const sameDay =
            schedPhx.getUTCFullYear() === phxNow.getUTCFullYear() &&
            schedPhx.getUTCMonth() === phxNow.getUTCMonth() &&
            schedPhx.getUTCDate() === phxNow.getUTCDate();
          if (!sameDay) continue;
        } else if (freq === 'weekly') {
          // Caregiver-picked days win; else the original scheduled weekday
          // (was ignoring repeatDays — alerted about a Wednesday-only
          // trash reminder on a Sunday, 2026-07-12)
          const weeklyDays: number[] = r.repeatDays || [];
          if (weeklyDays.length > 0) {
            if (!weeklyDays.includes(phxWeekday)) continue;
          } else {
            const schedWeekday = ((schedPhx.getUTCDay() + 6) % 7) + 1;
            if (schedWeekday !== phxWeekday) continue;
          }
        } else if (freq === 'custom') {
          if (!(r.repeatDays || []).includes(phxWeekday)) continue;
        } // daily: always scheduled

        // Today's occurrence (UTC instant of today-Phoenix @ sched hh:mm)
        const dueUtc = new Date(
          phxMidnightUtc.getTime() +
            schedPhx.getUTCHours() * 3600 * 1000 +
            schedPhx.getUTCMinutes() * 60 * 1000,
        );
        if (now.getTime() < dueUtc.getTime() + GRACE_MS) continue; // not late yet

        // Completed today? (failed verification already alerted separately)
        const completedAt = r.completedAt?.toDate?.();
        if (completedAt && completedAt >= phxMidnightUtc) continue;

        // Only one missed-task alert per reminder per day
        const lastAlert = r.lastMissedAlertAt?.toDate?.();
        if (lastAlert && lastAlert >= phxMidnightUtc) continue;

        const userDoc = await db.collection('users').doc(r.userId).get();
        const userName = userDoc.data()?.name || 'Your loved one';
        await notifyCaregiversAboutTask(
          r.userId,
          '⏰ Task not completed',
          `${userName} has not completed "${r.title}" ` +
            `(was due ${schedPhx.getUTCHours()}:` +
            `${String(schedPhx.getUTCMinutes()).padStart(2, '0')})`,
          doc.id,
        );
        await doc.ref.update({
          lastMissedAlertAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        alerted++;
      } catch (e) {
        console.error(`sweepMissedPhotoTasks: reminder ${doc.id} failed:`, e);
      }
    }
    console.log(
      `sweepMissedPhotoTasks: ${snap.size} candidates, ${alerted} alert(s)`,
    );
    return null;
  });

// ============================================================================
// ACCOUNT & PATIENT DELETION (Apple Guideline 5.1.1(v)) — 2026-07-13
// Admin SDK does the heavy lifting: recursive deletes and auth-user
// removal, avoiding client-side rules/recent-login traps.
// ============================================================================

/** Delete every doc a query matches, in chunks. */
async function deleteByQuery(
  query: FirebaseFirestore.Query,
): Promise<number> {
  const db = admin.firestore();
  let total = 0;
  // Loop in pages to stay under batch limits
  for (;;) {
    const snap = await query.limit(300).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    if (snap.size < 300) break;
  }
  return total;
}

/** Full wipe of one patient across all collections. */
async function wipePatient(patientId: string): Promise<void> {
  const db = admin.firestore();
  const byUserId = [
    'reminders',
    'medications',
    'medication_logs',
    'geo_zones',
    'geo_zone_events',
    'pet_feedings',
    'feeding_logs',
    'expenses',
    'task_completions',
    'notifications',
  ];
  for (const coll of byUserId) {
    const n = await deleteByQuery(
      db.collection(coll).where('userId', '==', patientId),
    );
    if (n > 0) console.log(`wipePatient ${patientId}: ${coll} -${n}`);
  }
  await deleteByQuery(
    db.collection('invite_codes').where('patientId', '==', patientId),
  );
  // Docs keyed BY the patient id
  for (const coll of ['bouncie_connections', 'trip_alerts']) {
    await db.collection(coll).doc(patientId).delete().catch(() => null);
  }
  // Remove from every caregiver's managedUserIds
  const carers = await db
    .collection('caregivers')
    .where('managedUserIds', 'array-contains', patientId)
    .get();
  for (const c of carers.docs) {
    await c.ref.update({
      managedUserIds: admin.firestore.FieldValue.arrayRemove(patientId),
      [`roleOverrides.${patientId}`]: admin.firestore.FieldValue.delete(),
      [`multiRoleOverrides.${patientId}`]:
        admin.firestore.FieldValue.delete(),
    });
  }
  // Patient doc + ALL subcollections (location_updates, zone_states, …)
  await db.recursiveDelete(db.collection('users').doc(patientId));
  console.log(`wipePatient ${patientId}: user doc + subcollections deleted`);
}

/**
 * Delete one patient. Caller must be that patient's primary caregiver.
 */
export const deletePatient = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        'unauthenticated', 'Sign in required.');
    }
    const patientId = String(data?.patientId || '');
    if (!patientId) {
      throw new functions.https.HttpsError(
        'invalid-argument', 'patientId required.');
    }
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(patientId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Patient not found.');
    }
    const u = userDoc.data()!;
    if (u.primaryCaregiverId && u.primaryCaregiverId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the primary caregiver can delete a patient.');
    }
    if (!u.primaryCaregiverId && !(u.caregiverIds || []).includes(uid)) {
      throw new functions.https.HttpsError(
        'permission-denied', 'Not a caregiver for this patient.');
    }
    await wipePatient(patientId);
    return { deleted: true };
  });

/**
 * Delete the CALLER's caregiver account (Apple 5.1.1(v)).
 * Patients solely cared for by this account are fully wiped; patients
 * with other caregivers are unlinked (primary reassigned if needed).
 * Finally deletes the Firebase Auth user.
 */
export const deleteCaregiverAccount = functions.https.onCall(
  async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        'unauthenticated', 'Sign in required.');
    }
    const db = admin.firestore();
    const caregiverDoc = await db.collection('caregivers').doc(uid).get();
    const managed: string[] = caregiverDoc.data()?.managedUserIds || [];

    let wiped = 0;
    let unlinked = 0;
    try {
    for (const patientId of managed) {
      const userDoc = await db.collection('users').doc(patientId).get();
      if (!userDoc.exists) continue;
      const u = userDoc.data()!;
      const others = (u.caregiverIds || []).filter(
        (id: string) => id !== uid,
      );
      if (others.length === 0) {
        await wipePatient(patientId);
        wiped++;
      } else {
        const update: Record<string, unknown> = {
          caregiverIds: admin.firestore.FieldValue.arrayRemove(uid),
        };
        if (u.primaryCaregiverId === uid) {
          update.primaryCaregiverId = others[0];
        }
        await userDoc.ref.update(update);
        unlinked++;
      }
    }
    await deleteByQuery(
      db.collection('invite_codes').where('createdBy', '==', uid),
    );
    await db.recursiveDelete(db.collection('caregivers').doc(uid));
    } catch (e) {
      console.error('deleteCaregiverAccount data cleanup failed:', e);
      throw new functions.https.HttpsError(
        'internal', `Account data cleanup failed: ${String((e as Error).message || e)}`);
    }
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      // Surface the REAL cause (e.g. missing roles/firebaseauth.admin on
      // the appspot service account) instead of a blank INTERNAL.
      console.error('auth deleteUser failed:', e);
      throw new functions.https.HttpsError(
        'internal',
        `Data deleted, but removing the sign-in account failed: ${String(
          (e as Error).message || e,
        )}`,
      );
    }
    console.log(
      `deleteCaregiverAccount ${uid}: wiped ${wiped}, unlinked ${unlinked}`);
    return { deleted: true, patientsWiped: wiped, patientsUnlinked: unlinked };
  });

// ═══════════════════════════════════════════════════════════════════════════
// HOME ENVIRONMENT (temperature / humidity) MONITORING
// ═══════════════════════════════════════════════════════════════════════════
//
// Polls each family's linked provider(s) in environment_connections/
// {patientId} — SensorPush Gateway Cloud API and/or Google Nest SDM —
// appends history to users/{id}/environment_readings, denormalizes the
// newest reading onto the connection doc (`latest`, which the dashboard
// card streams), and pushes FCM alerts to caregivers when readings cross
// the family's thresholds. Mirrors the analyzeTripsAndAlert pattern.
//
// Secrets (set with `firebase functions:secrets:set`):
//   NEST_FN_CLIENT_ID / NEST_FN_CLIENT_SECRET — Google OAuth client used
//     to refresh families' Nest tokens (same client as the app's .env
//     NEST_CLIENT_ID/SECRET).
//   NEST_FN_PROJECT_ID — Google Device Access project id.
// SensorPush needs no app credentials (per-family authorization token
// stored on the connection doc).

interface EnvReading {
  tempF: number;
  humidity: number;
  observedAt: Date;
  provider: 'sensorpush' | 'nest' | 'ble';
  sensorName: string | null;
}

const SENSORPUSH_BASE = 'https://api.sensorpush.com/api/v1';

async function fetchSensorPushReading(
  sp: Record<string, any>,
): Promise<EnvReading | null> {
  // authorization → short-lived access token
  const tokenRes = await fetch(`${SENSORPUSH_BASE}/oauth/accesstoken`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ authorization: sp.authorization }),
  });
  if (tokenRes.status === 401 || tokenRes.status === 403) {
    throw new EnvAuthError('sensorpush');
  }
  if (!tokenRes.ok) {
    throw new Error(`SensorPush accesstoken ${tokenRes.status}`);
  }
  const accesstoken = ((await tokenRes.json()) as any).accesstoken as string;

  const samplesRes = await fetch(`${SENSORPUSH_BASE}/samples`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: accesstoken,
    },
    body: JSON.stringify({ limit: 1, sensors: [sp.sensorId] }),
  });
  if (!samplesRes.ok) {
    throw new Error(`SensorPush samples ${samplesRes.status}`);
  }
  const body = (await samplesRes.json()) as any;
  const samples = body?.sensors?.[sp.sensorId] ?? [];
  if (!samples.length) return null;
  const s = samples[0];
  return {
    tempF: Number(s.temperature), // SensorPush reports °F
    humidity: Number(s.humidity),
    observedAt: s.observed ? new Date(s.observed) : new Date(),
    provider: 'sensorpush',
    sensorName: sp.sensorName ?? null,
  };
}

async function fetchNestReading(
  nest: Record<string, any>,
  clientId: string,
  clientSecret: string,
): Promise<EnvReading | null> {
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'refresh_token',
      refresh_token: nest.refreshToken,
    }),
  });
  if (tokenRes.status === 400 || tokenRes.status === 401) {
    throw new EnvAuthError('nest');
  }
  if (!tokenRes.ok) {
    throw new Error(`Nest token refresh ${tokenRes.status}`);
  }
  const accessToken = ((await tokenRes.json()) as any).access_token as string;

  const devRes = await fetch(
    `https://smartdevicemanagement.googleapis.com/v1/${nest.deviceName}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (devRes.status === 401 || devRes.status === 403) {
    throw new EnvAuthError('nest');
  }
  if (!devRes.ok) {
    throw new Error(`Nest device fetch ${devRes.status}`);
  }
  const device = (await devRes.json()) as any;
  const traits = device?.traits ?? {};
  const tempC =
    traits['sdm.devices.traits.Temperature']?.ambientTemperatureCelsius;
  if (typeof tempC !== 'number') return null;
  const humidity =
    traits['sdm.devices.traits.Humidity']?.ambientHumidityPercent ?? 0;
  return {
    tempF: (tempC * 9) / 5 + 32,
    humidity: Number(humidity),
    observedAt: new Date(),
    provider: 'nest',
    sensorName: nest.displayName ?? null,
  };
}

/** Provider credentials rejected — caregiver must re-link. */
class EnvAuthError extends Error {
  constructor(public readonly provider: 'sensorpush' | 'nest') {
    super(`${provider} auth failed`);
  }
}

/** Threshold violations for a reading. Keys are stable for cooldowns. */
function envViolations(
  reading: EnvReading,
  alerts: Record<string, any>,
): { key: string; text: string }[] {
  const minTempF = Number(alerts?.minTempF ?? 60);
  const maxTempF = Number(alerts?.maxTempF ?? 85);
  const minHum = Number(alerts?.minHumidity ?? 20);
  const maxHum = Number(alerts?.maxHumidity ?? 70);
  const t = reading.tempF.toFixed(0);
  const h = reading.humidity.toFixed(0);
  const out: { key: string; text: string }[] = [];
  if (reading.tempF > maxTempF) {
    out.push({ key: 'tempHigh', text: `${t}°F (limit ${maxTempF}°F)` });
  } else if (reading.tempF < minTempF) {
    out.push({ key: 'tempLow', text: `${t}°F (limit ${minTempF}°F)` });
  }
  if (reading.humidity > maxHum) {
    out.push({ key: 'humHigh', text: `${h}% humidity (limit ${maxHum}%)` });
  } else if (reading.humidity < minHum) {
    out.push({ key: 'humLow', text: `${h}% humidity (limit ${minHum}%)` });
  }
  return out;
}

const ENV_ALERT_COOLDOWN_MS = 6 * 3600 * 1000; // one alert per condition / 6h

/**
 * Threshold-check one reading and push FCM to the patient's caregivers,
 * respecting the per-condition cooldown in `alertState` on the
 * connection doc. Shared by pollEnvironment (cloud providers) and
 * onEnvironmentReading (BLE bridge readings from the patient phone).
 */
async function evaluateEnvironmentAlert(
  patientId: string,
  reading: EnvReading,
): Promise<void> {
  const db = admin.firestore();
  const connRef = db.collection('environment_connections').doc(patientId);
  const connDoc = await connRef.get();
  if (!connDoc.exists) return;
  const conn = connDoc.data()!;
  if (conn.alerts?.enabled === false) return;

  const violations = envViolations(reading, conn.alerts ?? {});
  if (!violations.length) return;

  const alertState: Record<string, any> = conn.alertState ?? {};
  const now = Date.now();
  const fresh = violations.filter((v) => {
    const last = alertState[v.key] as admin.firestore.Timestamp | undefined;
    return !last || now - last.toMillis() > ENV_ALERT_COOLDOWN_MS;
  });
  if (!fresh.length) return;

  const userDoc = await db.collection('users').doc(patientId).get();
  const userData = userDoc.data();
  const patientName = userData?.name ?? 'your family member';
  const caregiverIds: string[] = userData?.caregiverIds ?? [];
  if (!caregiverIds.length) return;
  const caregiverDocs = await Promise.all(
    caregiverIds.map((id) => db.collection('caregivers').doc(id).get()),
  );
  const tokens: string[] = [];
  for (const doc of caregiverDocs) {
    const cg = doc.data();
    if (cg?.fcmTokens?.length) tokens.push(...cg.fcmTokens);
    else if (cg?.fcmToken) tokens.push(cg.fcmToken);
  }
  if (!tokens.length) return;

  const body =
    `${patientName}'s home is at ` + fresh.map((v) => v.text).join(' and ');
  const response = await admin.messaging().sendEachForMulticast({
    notification: { title: '🌡️ Home environment alert', body },
    data: {
      type: 'environment_alert',
      userId: patientId,
      payload: `environment:${patientId}`,
    },
    tokens,
  });
  console.log(
    `Environment alert for ${patientId} (${fresh
      .map((v) => v.key)
      .join(',')}): ${response.successCount} ok, ` +
      `${response.failureCount} failed`,
  );

  const stateUpdate: Record<string, any> = {};
  for (const v of fresh) {
    stateUpdate[v.key] = admin.firestore.FieldValue.serverTimestamp();
  }
  await connRef.set({ alertState: stateUpdate }, { merge: true });
}

/**
 * Alerts for readings pushed by the patient-phone BLE bridge (SensorPush
 * HT.w without a WiFi gateway). Cloud-provider readings are alerted
 * inside pollEnvironment, so this only handles provider == 'ble'.
 */
export const onEnvironmentReading = functions.firestore
  .document('users/{userId}/environment_readings/{readingId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.provider !== 'ble') return null;
    const reading: EnvReading = {
      tempF: Number(data.tempF),
      humidity: Number(data.humidity ?? 0),
      observedAt:
        (data.timestamp as admin.firestore.Timestamp | undefined)?.toDate() ??
        new Date(),
      provider: 'ble',
      sensorName: data.sensorName ?? null,
    };
    try {
      await evaluateEnvironmentAlert(context.params.userId, reading);
    } catch (e) {
      console.error(
        `BLE environment alert failed for ${context.params.userId}:`,
        e,
      );
    }
    return null;
  });

export const pollEnvironment = functions
  .runWith({
    // Note: no NEST_FN_PROJECT_ID needed server-side — the stored
    // deviceName already embeds the Device Access project id.
    secrets: ['NEST_FN_CLIENT_ID', 'NEST_FN_CLIENT_SECRET'],
    timeoutSeconds: 300,
  })
  .pubsub.schedule('every 30 minutes')
  .onRun(async () => {
    const nestClientId = (process.env.NEST_FN_CLIENT_ID || '').trim();
    const nestClientSecret = (process.env.NEST_FN_CLIENT_SECRET || '').trim();

    const db = admin.firestore();
    const connections = await db.collection('environment_connections').get();
    if (connections.empty) return null;
    console.log(`Environment poll: ${connections.size} connection(s)`);

    for (const connDoc of connections.docs) {
      const patientId = connDoc.id;
      const conn = connDoc.data();
      try {
        // Prefer the dedicated sensor; fall back to the thermostat.
        let reading: EnvReading | null = null;
        const authFailures: ('sensorpush' | 'nest')[] = [];

        if (conn.sensorpush && conn.sensorpush.needsReauth !== true) {
          try {
            reading = await fetchSensorPushReading(conn.sensorpush);
          } catch (e) {
            if (e instanceof EnvAuthError) authFailures.push(e.provider);
            else console.error(`SensorPush poll failed for ${patientId}:`, e);
          }
        }
        if (
          !reading &&
          conn.nest &&
          conn.nest.needsReauth !== true &&
          nestClientId &&
          nestClientSecret
        ) {
          try {
            reading = await fetchNestReading(
              conn.nest,
              nestClientId,
              nestClientSecret,
            );
          } catch (e) {
            if (e instanceof EnvAuthError) authFailures.push(e.provider);
            else console.error(`Nest poll failed for ${patientId}:`, e);
          }
        }

        // Gather patient + caregiver tokens once (used by both alert paths).
        const userDoc = await db.collection('users').doc(patientId).get();
        const userData = userDoc.data();
        const patientName = userData?.name ?? 'your family member';
        const caregiverIds: string[] = userData?.caregiverIds ?? [];
        const tokens: string[] = [];
        if (caregiverIds.length) {
          const caregiverDocs = await Promise.all(
            caregiverIds.map((id) => db.collection('caregivers').doc(id).get()),
          );
          for (const doc of caregiverDocs) {
            const cg = doc.data();
            if (cg?.fcmTokens?.length) tokens.push(...cg.fcmTokens);
            else if (cg?.fcmToken) tokens.push(cg.fcmToken);
          }
        }

        // Flag dead credentials once and tell the caregivers.
        for (const provider of authFailures) {
          await connDoc.ref.set(
            { [provider]: { needsReauth: true } },
            { merge: true },
          );
          if (tokens.length) {
            await admin.messaging().sendEachForMulticast({
              notification: {
                title: '🌡️ Home sensor disconnected',
                body:
                  `The ${provider === 'nest' ? 'Nest' : 'SensorPush'} link ` +
                  `for ${patientName} stopped working — open Home ` +
                  'Environment settings to re-connect it.',
              },
              data: {
                type: 'environment_reauth',
                userId: patientId,
                payload: `environment:${patientId}`,
              },
              tokens,
            });
          }
          console.log(`Environment ${provider} needsReauth set for ${patientId}`);
        }

        if (!reading) continue;

        // History + denormalized latest.
        const observedTs = admin.firestore.Timestamp.fromDate(
          reading.observedAt,
        );
        await db
          .collection('users')
          .doc(patientId)
          .collection('environment_readings')
          .add({
            provider: reading.provider,
            sensorName: reading.sensorName,
            tempF: reading.tempF,
            humidity: reading.humidity,
            timestamp: observedTs,
          });
        await connDoc.ref.set(
          {
            latest: {
              tempF: reading.tempF,
              humidity: reading.humidity,
              observedAt: observedTs,
              provider: reading.provider,
              sensorName: reading.sensorName,
            },
          },
          { merge: true },
        );

        // Threshold alerts — shared with the BLE reading trigger
        // (per-condition 6h cooldown in alertState).
        await evaluateEnvironmentAlert(patientId, reading);
      } catch (e) {
        console.error(`Environment poll failed for ${patientId}:`, e);
      }
    }
    return null;
  });
