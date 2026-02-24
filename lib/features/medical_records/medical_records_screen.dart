import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/providers.dart';
import '../../core/services/medical_records_service.dart';
import '../../core/models/medication.dart';
import '../../core/theme/app_theme.dart';

/// Screen for viewing and exporting medical records as PDF.
class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
  final _service = MedicalRecordsService();
  MedicalRecordsSummary? _summary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = ref.read(caregiverNotifierProvider);
      final user = provider.selectedUser;
      if (user == null) {
        setState(() {
          _error = 'No patient selected';
          _isLoading = false;
        });
        return;
      }

      final summary = await _service.compileRecords(
        userId: user.id,
        patient: user,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load records: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _previewPdf() async {
    if (_summary == null) return;

    try {
      final pdfBytes = await _service.generatePdf(_summary!);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.primaryBlue,
              title: const Text('PDF Preview'),
            ),
            body: PdfPreview(
              build: (_) => pdfBytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName:
                  'medical_records_${_summary!.patient.name.replaceAll(' ', '_')}.pdf',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_summary == null) return;

    try {
      final pdfBytes = await _service.generatePdf(_summary!);
      final dir = await getTemporaryDirectory();
      final fileName =
          'medical_records_${_summary!.patient.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject:
              'Medical Records — ${_summary!.patient.name}',
          text:
              'Medical records report for ${_summary!.patient.name}, generated ${DateFormat.yMMMd().format(DateTime.now())} via Lumina Care App.',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    if (_summary == null) return;

    try {
      final pdfBytes = await _service.generatePdf(_summary!);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Medical Records'),
        actions: [
          if (_summary != null) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print',
              onPressed: _printPdf,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF',
              onPressed: _sharePdf,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Compiling medical records...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.primaryRed),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecords,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
      floatingActionButton: _summary != null
          ? FloatingActionButton.extended(
              onPressed: _previewPdf,
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('View PDF',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final summary = _summary!;
    final dateFmt = DateFormat('MMM d, yyyy');
    final dateTimeFmt = DateFormat('MMM d, h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Patient header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppTheme.primaryBlue.withValues(alpha: 0.1),
                    child: Text(
                      summary.patient.name.isNotEmpty
                          ? summary.patient.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.patient.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Report generated ${dateFmt.format(summary.generatedAt)}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Adherence stats
          if (summary.recentLogs.isNotEmpty) ...[
            const Text(
              'Medication Adherence (30 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatCard(
                    'Taken', '${summary.totalTaken}', AppTheme.primaryGreen),
                const SizedBox(width: 8),
                _buildStatCard(
                    'Missed', '${summary.totalMissed}', AppTheme.primaryRed),
                const SizedBox(width: 8),
                _buildStatCard(
                  'Adherence',
                  '${(summary.adherenceRate * 100).toStringAsFixed(0)}%',
                  summary.adherenceRate >= 0.8
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryRed,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Medications
          _buildSection(
            'Active Medications',
            Icons.medication,
            AppTheme.primaryOrange,
            summary.medications.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No medications on file.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : summary.medications.map((m) => _buildMedCard(m)).toList(),
          ),
          const SizedBox(height: 12),

          // Prescriptions
          _buildSection(
            'Prescriptions',
            Icons.receipt_long,
            Colors.deepPurple,
            summary.prescriptions.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No prescriptions on file.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : summary.prescriptions.map((rx) => _buildRxCard(rx)).toList(),
          ),
          const SizedBox(height: 12),

          // Recent logs
          _buildSection(
            'Recent Medication Logs',
            Icons.history,
            AppTheme.primaryPurple,
            summary.recentLogs.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No logs in the last 30 days.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  ]
                : summary.recentLogs
                    .take(20)
                    .map((log) => _buildLogItem(log, dateTimeFmt))
                    .toList(),
          ),
          const SizedBox(height: 24),

          // Action buttons
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text(
                'SHARE WITH MEDICAL PROVIDER',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _printPdf,
              icon: const Icon(Icons.print),
              label: const Text(
                'PRINT RECORDS',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMedCard(Medication m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: m.isActive ? AppTheme.primaryGreen : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (m.dosage != null)
                  Text(m.dosage!,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (m.schedules.isNotEmpty)
            Text(
              m.schedules.map((s) => s.timeString).join(', '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  Widget _buildRxCard(dynamic rx) {
    final statusColor = rx.status.name == 'active'
        ? AppTheme.primaryGreen
        : AppTheme.primaryOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rx.medicationName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${rx.dosage} — ${rx.frequency}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
                if (rx.prescribedBy != null)
                  Text('Dr. ${rx.prescribedBy}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rx.status.name.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(MedicationLog log, DateFormat fmt) {
    final statusColor = log.status == MedicationLogStatus.taken
        ? AppTheme.primaryGreen
        : log.status == MedicationLogStatus.missed
            ? AppTheme.primaryRed
            : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            log.status == MedicationLogStatus.taken
                ? Icons.check_circle
                : log.status == MedicationLogStatus.missed
                    ? Icons.cancel
                    : Icons.schedule,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fmt.format(log.scheduledTime),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              log.status.displayName,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor),
            ),
          ),
          if (log.verifiedByComparison)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.verified, color: AppTheme.primaryGreen, size: 16),
            ),
        ],
      ),
    );
  }
}
