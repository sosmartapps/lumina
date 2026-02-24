import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/services/prescription_scan_service.dart';
import '../../core/models/prescription.dart';
import '../../core/theme/app_theme.dart';

/// Screen for scanning a prescription label via camera OCR.
class ScanPrescriptionScreen extends ConsumerStatefulWidget {
  const ScanPrescriptionScreen({super.key});

  @override
  ConsumerState<ScanPrescriptionScreen> createState() =>
      _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState
    extends ConsumerState<ScanPrescriptionScreen> {
  final _scanService = PrescriptionScanService();
  PrescriptionScanResult? _scanResult;
  bool _isScanning = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Editable controllers pre-filled from scan
  final _rxController = TextEditingController();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _doctorController = TextEditingController();
  final _pharmacyController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _quantityController = TextEditingController();
  final _refillsController = TextEditingController();

  @override
  void dispose() {
    _scanService.dispose();
    _rxController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _doctorController.dispose();
    _pharmacyController.dispose();
    _instructionsController.dispose();
    _quantityController.dispose();
    _refillsController.dispose();
    super.dispose();
  }

  Future<void> _scan({required bool fromCamera}) async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final result = fromCamera
          ? await _scanService.scanFromCamera()
          : await _scanService.scanFromGallery();

      if (result == null) {
        setState(() => _isScanning = false);
        return;
      }

      setState(() {
        _scanResult = result;
        _isScanning = false;
        _rxController.text = result.rxNumber ?? '';
        _nameController.text = result.medicationName ?? '';
        _dosageController.text = result.dosage ?? '';
        _frequencyController.text = result.frequency ?? '';
        _doctorController.text = result.prescribedBy ?? '';
        _pharmacyController.text = result.pharmacyName ?? '';
        _instructionsController.text = result.instructions ?? '';
        _quantityController.text =
            result.quantity?.toString() ?? '';
        _refillsController.text =
            result.refills?.toString() ?? '';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Scan failed: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Medication name is required');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final provider = ref.read(caregiverNotifierProvider);
      final user = provider.selectedUser;
      if (user == null) return;

      final reminderService = ref.read(reminderServiceProvider);

      final prescription = Prescription(
        id: '',
        userId: user.id,
        medicationName: _nameController.text.trim(),
        dosage: _dosageController.text.trim().isEmpty
            ? ''
            : _dosageController.text.trim(),
        frequency: _frequencyController.text.trim().isEmpty
            ? ''
            : _frequencyController.text.trim(),
        rxNumber: _rxController.text.trim().isEmpty
            ? null
            : _rxController.text.trim(),
        prescribedBy: _doctorController.text.trim().isEmpty
            ? null
            : _doctorController.text.trim(),
        pharmacyName: _pharmacyController.text.trim().isEmpty
            ? null
            : _pharmacyController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        totalQuantity: int.tryParse(_quantityController.text.trim()),
        remainingQuantity: int.tryParse(_quantityController.text.trim()),
        refillsRemaining: int.tryParse(_refillsController.text.trim()),
        refillsTotal: int.tryParse(_refillsController.text.trim()),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await reminderService.createPrescription(prescription);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: const Text('Scan Prescription'),
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing image...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_scanResult == null) ...[
                    _buildScanPrompt(),
                  ] else ...[
                    _buildScanResultForm(),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.primaryRed),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildScanPrompt() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.document_scanner,
            size: 64,
            color: AppTheme.primaryOrange,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Scan a Prescription Label',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Take a photo of the pill bottle label or prescription sheet. '
          'We\'ll extract the medication name, RX number, dosage, and more.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _scan(fromCamera: true),
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              'TAKE PHOTO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _scan(fromCamera: false),
            icon: const Icon(Icons.photo_library),
            label: const Text(
              'CHOOSE FROM GALLERY',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryOrange,
              side: const BorderSide(color: AppTheme.primaryOrange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            // Let user skip scan and manually enter
            setState(() {
              _scanResult = PrescriptionScanResult(rawText: '');
            });
          },
          child: const Text(
            'Enter Manually Instead',
            style: TextStyle(fontSize: 16, color: AppTheme.primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildScanResultForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Re-scan button
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Review & edit the scanned fields',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: () => _scan(fromCamera: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-scan'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildField(_nameController, 'Medication Name *', Icons.medication),
        _buildField(_rxController, 'RX Number', Icons.tag),
        _buildField(_dosageController, 'Dosage', Icons.scale),
        _buildField(_frequencyController, 'Frequency', Icons.schedule),
        _buildField(_doctorController, 'Prescribing Doctor', Icons.person),
        _buildField(_pharmacyController, 'Pharmacy', Icons.local_pharmacy),
        _buildField(_instructionsController, 'Instructions', Icons.notes,
            maxLines: 2),
        Row(
          children: [
            Expanded(
              child: _buildField(
                  _quantityController, 'Quantity', Icons.inventory,
                  keyboardType: TextInputType.number),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                  _refillsController, 'Refills', Icons.replay,
                  keyboardType: TextInputType.number),
            ),
          ],
        ),

        if (_scanResult != null && _scanResult!.rawText.isNotEmpty) ...[
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Raw OCR Text'),
            tilePadding: EdgeInsets.zero,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scanResult!.rawText,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'SAVE PRESCRIPTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
