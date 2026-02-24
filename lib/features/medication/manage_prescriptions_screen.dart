import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/prescription.dart';
import 'scan_prescription_screen.dart';

/// Screen for managing prescriptions with scan, view, and edit capabilities.
class ManagePrescriptionsScreen extends ConsumerStatefulWidget {
  const ManagePrescriptionsScreen({super.key});

  @override
  ConsumerState<ManagePrescriptionsScreen> createState() =>
      _ManagePrescriptionsScreenState();
}

class _ManagePrescriptionsScreenState
    extends ConsumerState<ManagePrescriptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: const Text('Prescriptions'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
        ),
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan Rx'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final reminderService = ref.read(reminderServiceProvider);

          return StreamBuilder<List<Prescription>>(
            stream: reminderService.getPrescriptions(user.id),
            builder: (context, snapshot) {
              final prescriptions = snapshot.data ?? [];

              if (prescriptions.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: prescriptions.length,
                itemBuilder: (context, index) =>
                    _buildPrescriptionCard(prescriptions[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No prescriptions yet',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a pill bottle label to add a prescription automatically',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ScanPrescriptionScreen()),
              ),
              icon: const Icon(Icons.document_scanner, color: Colors.white),
              label: const Text('Scan Prescription',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(Prescription rx) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isExpired = rx.isExpired;
    final needsRefill = rx.needsRefillSoon;
    final noRefills = rx.noRefillsRemaining;

    Color statusColor = AppTheme.primaryGreen;
    String statusLabel = 'Active';
    if (rx.status == PrescriptionStatus.discontinued) {
      statusColor = Colors.grey;
      statusLabel = 'Discontinued';
    } else if (rx.status == PrescriptionStatus.onHold) {
      statusColor = AppTheme.primaryOrange;
      statusLabel = 'On Hold';
    } else if (isExpired) {
      statusColor = AppTheme.primaryRed;
      statusLabel = 'Expired';
    } else if (needsRefill) {
      statusColor = AppTheme.primaryOrange;
      statusLabel = 'Refill Soon';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long, color: statusColor),
        ),
        title: Text(
          rx.medicationName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rx.dosage.isNotEmpty)
              Text('${rx.dosage} — ${rx.frequency}'),
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (noRefills) ...[
                  const SizedBox(width: 6),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No Refills',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (rx.rxNumber != null) _detailRow('RX #', rx.rxNumber!),
                if (rx.prescribedBy != null)
                  _detailRow('Doctor', rx.prescribedBy!),
                if (rx.pharmacyName != null)
                  _detailRow('Pharmacy', rx.pharmacyName!),
                if (rx.instructions != null)
                  _detailRow('Instructions', rx.instructions!),
                if (rx.totalQuantity != null)
                  _detailRow('Quantity', '${rx.totalQuantity}'),
                if (rx.remainingQuantity != null)
                  _detailRow('Remaining', '${rx.remainingQuantity}'),
                if (rx.refillsRemaining != null && rx.refillsTotal != null)
                  _detailRow(
                      'Refills', '${rx.refillsRemaining} of ${rx.refillsTotal}'),
                if (rx.lastFilledDate != null)
                  _detailRow('Last Filled', dateFormat.format(rx.lastFilledDate!)),
                if (rx.nextRefillDate != null)
                  _detailRow(
                      'Next Refill', dateFormat.format(rx.nextRefillDate!)),
                if (rx.expirationDate != null)
                  _detailRow('Expires', dateFormat.format(rx.expirationDate!)),
                if (rx.reason != null) _detailRow('Reason', rx.reason!),
                if (rx.sideEffects != null)
                  _detailRow('Side Effects', rx.sideEffects!),
                if (rx.warnings != null) _detailRow('Warnings', rx.warnings!),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDialog(rx),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirmation(rx),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Prescription rx) {
    final nameCtrl = TextEditingController(text: rx.medicationName);
    final rxCtrl = TextEditingController(text: rx.rxNumber ?? '');
    final dosageCtrl = TextEditingController(text: rx.dosage);
    final freqCtrl = TextEditingController(text: rx.frequency);
    final doctorCtrl = TextEditingController(text: rx.prescribedBy ?? '');
    final pharmacyCtrl = TextEditingController(text: rx.pharmacyName ?? '');
    final instrCtrl = TextEditingController(text: rx.instructions ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Medication Name *')),
              const SizedBox(height: 8),
              TextField(
                  controller: rxCtrl,
                  decoration: const InputDecoration(labelText: 'RX Number')),
              const SizedBox(height: 8),
              TextField(
                  controller: dosageCtrl,
                  decoration: const InputDecoration(labelText: 'Dosage')),
              const SizedBox(height: 8),
              TextField(
                  controller: freqCtrl,
                  decoration: const InputDecoration(labelText: 'Frequency')),
              const SizedBox(height: 8),
              TextField(
                  controller: doctorCtrl,
                  decoration: const InputDecoration(labelText: 'Doctor')),
              const SizedBox(height: 8),
              TextField(
                  controller: pharmacyCtrl,
                  decoration: const InputDecoration(labelText: 'Pharmacy')),
              const SizedBox(height: 8),
              TextField(
                  controller: instrCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Instructions'),
                  maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final reminderService = ref.read(reminderServiceProvider);
              final updated = rx.copyWith(
                medicationName: nameCtrl.text.trim(),
                rxNumber: rxCtrl.text.trim().isEmpty
                    ? null
                    : rxCtrl.text.trim(),
                dosage: dosageCtrl.text.trim(),
                frequency: freqCtrl.text.trim(),
                prescribedBy: doctorCtrl.text.trim().isEmpty
                    ? null
                    : doctorCtrl.text.trim(),
                pharmacyName: pharmacyCtrl.text.trim().isEmpty
                    ? null
                    : pharmacyCtrl.text.trim(),
                instructions: instrCtrl.text.trim().isEmpty
                    ? null
                    : instrCtrl.text.trim(),
              );
              await reminderService.updatePrescription(updated);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Prescription rx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: Text('Remove ${rx.medicationName} prescription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reminderService = ref.read(reminderServiceProvider);
              await reminderService.deletePrescription(rx.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
