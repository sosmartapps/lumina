"use strict";
/**
 * Firebase Cloud Functions for Lumina App
 *
 * Features:
 * - Email notifications when new feedback is received
 * - Caregiver notifications for geofence events
 * - Medication reminder alerts
 * - Error reporting
 */
var _a, _b, _c;
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupOldFeedback = exports.createRepairTaskFromShare = exports.sendErrorAlert = exports.sendMedicationAlert = exports.sendGeofenceAlert = exports.sendFeedbackEmail = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();
// ============================================================================
// CONFIGURATION
// ============================================================================
// Email configuration
// Set these in Firebase Functions config:
// firebase functions:config:set email.user="your-email@gmail.com" email.pass="your-app-password"
// firebase functions:config:set email.admin="admin@yourcompany.com"
const EMAIL_USER = ((_a = functions.config().email) === null || _a === void 0 ? void 0 : _a.user) || process.env.EMAIL_USER;
const EMAIL_PASS = ((_b = functions.config().email) === null || _b === void 0 ? void 0 : _b.pass) || process.env.EMAIL_PASS;
const ADMIN_EMAIL = ((_c = functions.config().email) === null || _c === void 0 ? void 0 : _c.admin) || process.env.ADMIN_EMAIL || EMAIL_USER;
// Create reusable transporter
let transporter = null;
function getTransporter() {
    if (!transporter && EMAIL_USER && EMAIL_PASS) {
        transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: EMAIL_USER,
                pass: EMAIL_PASS,
            },
        });
    }
    return transporter;
}
// ============================================================================
// SCREENSHOT FEEDBACK EMAIL NOTIFICATIONS
// ============================================================================
/**
 * Send email when new feedback is submitted
 */
exports.sendFeedbackEmail = functions.firestore
    .document('feedback/{feedbackId}')
    .onCreate(async (snap, context) => {
    var _a, _b, _c;
    const data = snap.data();
    const feedbackId = context.params.feedbackId;
    if (!EMAIL_USER || !EMAIL_PASS) {
        console.warn('Email not configured. Skipping feedback email notification.');
        return null;
    }
    try {
        // Build email content
        const subject = `Lumina Feedback: ${data.type || 'General'} - ${((_a = data.text) === null || _a === void 0 ? void 0 : _a.substring(0, 50)) || 'No description'}`;
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
                <div class="value">${((_c = (_b = data.createdAt) === null || _b === void 0 ? void 0 : _b.toDate) === null || _c === void 0 ? void 0 : _c.call(_b)) || new Date()}</div>
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
                    ${data.attachments.map((a) => `
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
    }
    catch (error) {
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
exports.sendGeofenceAlert = functions.firestore
    .document('users/{userId}/location_updates/{updateId}')
    .onCreate(async (snap, context) => {
    var _a, _b, _c;
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
        const caregiverDocs = await Promise.all(userData.caregiverIds.map((id) => admin.firestore().collection('caregivers').doc(id).get()));
        const tokens = [];
        caregiverDocs.forEach(doc => {
            const caregiverData = doc.data();
            if (caregiverData === null || caregiverData === void 0 ? void 0 : caregiverData.fcmToken) {
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
                timestamp: ((_c = (_b = (_a = data.timestamp) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString()) || new Date().toISOString(),
            },
            tokens,
        };
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Sent ${response.successCount} geofence notifications, ${response.failureCount} failed`);
        return null;
    }
    catch (error) {
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
exports.sendMedicationAlert = functions.firestore
    .document('medications/{medicationId}/logs/{logId}')
    .onCreate(async (snap, context) => {
    var _a, _b, _c;
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
        const caregiverDocs = await Promise.all(userData.caregiverIds.map((id) => admin.firestore().collection('caregivers').doc(id).get()));
        const tokens = [];
        caregiverDocs.forEach(doc => {
            const caregiverData = doc.data();
            if (caregiverData === null || caregiverData === void 0 ? void 0 : caregiverData.fcmToken) {
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
                timestamp: ((_c = (_b = (_a = data.scheduledTime) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString()) || new Date().toISOString(),
            },
            tokens,
        };
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Sent ${response.successCount} medication notifications, ${response.failureCount} failed`);
        return null;
    }
    catch (error) {
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
exports.sendErrorAlert = functions.firestore
    .document('errors/{errorId}')
    .onCreate(async (snap, context) => {
    var _a, _b, _c, _d, _e;
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
        const subject = `🚨 Lumina ${(_a = data.level) === null || _a === void 0 ? void 0 : _a.toUpperCase()} Error: ${(_b = data.message) === null || _b === void 0 ? void 0 : _b.substring(0, 50)}`;
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
              <h1>🚨 ${(_c = data.level) === null || _c === void 0 ? void 0 : _c.toUpperCase()} Error Alert</h1>
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
                <div class="value">${((_e = (_d = data.timestamp) === null || _d === void 0 ? void 0 : _d.toDate) === null || _e === void 0 ? void 0 : _e.call(_d)) || new Date()}</div>
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
    }
    catch (error) {
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
exports.createRepairTaskFromShare = functions
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
        let imageData = null;
        if (contentType.includes('multipart/form-data')) {
            // Parse multipart form data
            const busboy = require('busboy');
            const bb = busboy({ headers: req.headers });
            const fields = {};
            let imageBuffer = [];
            await new Promise((resolve, reject) => {
                bb.on('field', (name, val) => {
                    fields[name] = val;
                });
                bb.on('file', (name, file, info) => {
                    file.on('data', (data) => {
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
        }
        else {
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
        const taskData = {
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
    }
    catch (error) {
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
exports.cleanupOldFeedback = functions.pubsub
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
//# sourceMappingURL=index.js.map