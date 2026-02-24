import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/app_user.dart';
import '../models/medication.dart';
import '../models/prescription.dart';

/// Compiled medical records for a patient.
class MedicalRecordsSummary {
  final AppUser patient;
  final List<Medication> medications;
  final List<Prescription> prescriptions;
  final List<MedicationLog> recentLogs;
  final DateTime generatedAt;

  MedicalRecordsSummary({
    required this.patient,
    required this.medications,
    required this.prescriptions,
    required this.recentLogs,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Stats helpers
  int get totalTaken =>
      recentLogs.where((l) => l.status == MedicationLogStatus.taken).length;
  int get totalMissed =>
      recentLogs.where((l) => l.status == MedicationLogStatus.missed).length;
  int get totalSkipped =>
      recentLogs.where((l) => l.status == MedicationLogStatus.skipped).length;
  double get adherenceRate =>
      recentLogs.isEmpty ? 0 : totalTaken / recentLogs.length;
}

/// Service for compiling and exporting medical records.
class MedicalRecordsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Compile all medical records for a patient.
  Future<MedicalRecordsSummary> compileRecords({
    required String userId,
    required AppUser patient,
    int logDays = 30,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: logDays));

    // Fetch medications
    final medsSnap = await _firestore
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .get();
    final medications =
        medsSnap.docs.map((d) => Medication.fromFirestore(d)).toList();

    // Fetch prescriptions
    final rxSnap = await _firestore
        .collection('prescriptions')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .get();
    final prescriptions =
        rxSnap.docs.map((d) => Prescription.fromFirestore(d)).toList();

    // Fetch recent medication logs
    final logsSnap = await _firestore
        .collection('medication_logs')
        .where('userId', isEqualTo: userId)
        .where('scheduledTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('scheduledTime', descending: true)
        .get();
    final logs =
        logsSnap.docs.map((d) => MedicationLog.fromFirestore(d)).toList();

    return MedicalRecordsSummary(
      patient: patient,
      medications: medications,
      prescriptions: prescriptions,
      recentLogs: logs,
    );
  }

  /// Generate a PDF document from compiled records.
  Future<Uint8List> generatePdf(MedicalRecordsSummary summary) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    final dateFmt = DateFormat('MMM d, yyyy');
    final dateTimeFmt = DateFormat('MMM d, yyyy h:mm a');

    // Colors
    const headerColor = PdfColor.fromInt(0xFF1565C0);
    const greenColor = PdfColor.fromInt(0xFF2E7D32);
    const redColor = PdfColor.fromInt(0xFFD32F2F);
    const orangeColor = PdfColor.fromInt(0xFFEF6C00);
    const greyColor = PdfColor.fromInt(0xFF757575);

    // ── Page 1: Patient Info + Medications ──────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPageHeader(
          summary,
          'Medical Records Report',
          headerColor,
          dateFmt,
        ),
        footer: (context) => _buildPageFooter(context),
        build: (context) => [
          // Patient Info
          _buildSectionTitle('Patient Information', headerColor),
          pw.SizedBox(height: 8),
          _buildInfoRow('Name', summary.patient.name),
          if (summary.patient.phoneNumber != null)
            _buildInfoRow('Phone', summary.patient.phoneNumber!),
          if (summary.patient.homeAddress != null)
            _buildInfoRow('Home Address', summary.patient.homeAddress!),
          pw.SizedBox(height: 8),

          // Emergency Contacts
          if (summary.patient.emergencyContacts.isNotEmpty) ...[
            _buildSubSectionTitle('Emergency Contacts'),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableHeader('Name'),
                    _tableHeader('Phone'),
                    _tableHeader('Relationship'),
                  ],
                ),
                ...summary.patient.emergencyContacts.map(
                  (c) => pw.TableRow(children: [
                    _tableCell(c.name),
                    _tableCell(c.phoneNumber),
                    _tableCell(c.relationship ?? '—'),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // Active Medications
          _buildSectionTitle('Current Medications', headerColor),
          pw.SizedBox(height: 8),
          if (summary.medications.isEmpty)
            pw.Text('No medications on file.',
                style: pw.TextStyle(
                    color: greyColor, fontStyle: pw.FontStyle.italic))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableHeader('Medication'),
                    _tableHeader('Dosage'),
                    _tableHeader('Schedule'),
                    _tableHeader('Status'),
                  ],
                ),
                ...summary.medications.map(
                  (m) => pw.TableRow(children: [
                    _tableCell(m.name),
                    _tableCell(m.dosage ?? '—'),
                    _tableCell(m.schedules.isNotEmpty
                        ? m.schedules.map((s) => s.timeString).join(', ')
                        : '—'),
                    _tableCell(m.isActive ? 'Active' : 'Inactive'),
                  ]),
                ),
              ],
            ),
          pw.SizedBox(height: 16),

          // Prescriptions
          _buildSectionTitle('Prescriptions', headerColor),
          pw.SizedBox(height: 8),
          if (summary.prescriptions.isEmpty)
            pw.Text('No prescriptions on file.',
                style: pw.TextStyle(
                    color: greyColor, fontStyle: pw.FontStyle.italic))
          else
            ...summary.prescriptions.map((rx) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(rx.medicationName,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12)),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: rx.status == PrescriptionStatus.active
                                  ? const PdfColor.fromInt(0xFFE8F5E9)
                                  : const PdfColor.fromInt(0xFFFFF3E0),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              rx.status.name.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color:
                                    rx.status == PrescriptionStatus.active
                                        ? greenColor
                                        : orangeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('${rx.dosage} — ${rx.frequency}',
                          style: const pw.TextStyle(fontSize: 10)),
                      if (rx.rxNumber != null)
                        pw.Text('RX# ${rx.rxNumber}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: greyColor)),
                      if (rx.prescribedBy != null)
                        pw.Text('Prescribed by: ${rx.prescribedBy}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: greyColor)),
                      if (rx.pharmacyName != null)
                        pw.Text('Pharmacy: ${rx.pharmacyName}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: greyColor)),
                      if (rx.instructions != null)
                        pw.Text('Instructions: ${rx.instructions}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (rx.refillsRemaining != null)
                        pw.Text(
                            'Refills remaining: ${rx.refillsRemaining}/${rx.refillsTotal ?? "?"}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: greyColor)),
                      if (rx.sideEffects != null)
                        pw.Text('Side effects: ${rx.sideEffects}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: greyColor)),
                      if (rx.warnings != null)
                        pw.Text('Warnings: ${rx.warnings}',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: redColor,
                                fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                )),
          pw.SizedBox(height: 16),

          // Adherence Summary
          _buildSectionTitle('Medication Adherence (Last 30 Days)',
              headerColor),
          pw.SizedBox(height: 8),
          if (summary.recentLogs.isEmpty)
            pw.Text('No medication logs in this period.',
                style: pw.TextStyle(
                    color: greyColor, fontStyle: pw.FontStyle.italic))
          else ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox(
                    'Taken', '${summary.totalTaken}', greenColor),
                _buildStatBox(
                    'Missed', '${summary.totalMissed}', redColor),
                _buildStatBox(
                    'Skipped', '${summary.totalSkipped}', orangeColor),
                _buildStatBox(
                  'Adherence',
                  '${(summary.adherenceRate * 100).toStringAsFixed(0)}%',
                  summary.adherenceRate >= 0.8 ? greenColor : redColor,
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Recent log entries
            _buildSubSectionTitle('Recent Log Entries'),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableHeader('Scheduled'),
                    _tableHeader('Status'),
                    _tableHeader('Taken At'),
                    _tableHeader('Verified'),
                  ],
                ),
                ...summary.recentLogs.take(50).map(
                      (log) => pw.TableRow(children: [
                        _tableCell(
                            dateTimeFmt.format(log.scheduledTime)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            log.status.displayName,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color:
                                  log.status == MedicationLogStatus.taken
                                      ? greenColor
                                      : log.status ==
                                              MedicationLogStatus.missed
                                          ? redColor
                                          : orangeColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        _tableCell(log.takenTime != null
                            ? dateTimeFmt.format(log.takenTime!)
                            : '—'),
                        _tableCell(log.verifiedByComparison
                            ? 'Yes'
                            : '—'),
                      ]),
                    ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ── PDF Helpers ───────────────────────────────────────────────────────

  pw.Widget _buildPageHeader(
    MedicalRecordsSummary summary,
    String title,
    PdfColor color,
    DateFormat dateFmt,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: color),
              ),
              pw.Text(
                'Patient: ${summary.patient.name}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Lumina Care App',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: color),
              ),
              pw.Text(
                'Generated: ${dateFmt.format(summary.generatedAt)}',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromInt(0xFF757575)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CONFIDENTIAL — For authorized medical use only',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFD32F2F),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildSubSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF424242),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(
      String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColor.fromInt(0xFF757575))),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style:
              pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}
