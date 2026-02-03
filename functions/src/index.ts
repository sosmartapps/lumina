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
