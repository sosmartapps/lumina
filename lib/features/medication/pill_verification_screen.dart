import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/providers.dart';
import '../../core/services/pill_photo_service.dart';
import '../../core/models/medication.dart';
import '../../core/theme/app_theme.dart';

/// Screen for capturing and managing pill container / organizer photos.
///
/// Supports three workflows:
/// 1. Reference photos — capture what the full container and filled organizer look like.
/// 2. Verification — at medication time, compare a new photo against the reference.
/// 3. Empty confirmation — photograph the empty organizer compartment to confirm meds were taken.
class PillVerificationScreen extends ConsumerStatefulWidget {
  final Medication medication;

  const PillVerificationScreen({super.key, required this.medication});

  @override
  ConsumerState<PillVerificationScreen> createState() =>
      _PillVerificationScreenState();
}

class _PillVerificationScreenState
    extends ConsumerState<PillVerificationScreen> {
  final _photoService = PillPhotoService();
  bool _isUploading = false;
  File? _capturedFile;
  PhotoComparisonResult? _comparisonResult;
  String? _errorMessage;

  Future<void> _captureAndUpload(PillPhotoType type) async {
    setState(() {
      _errorMessage = null;
      _capturedFile = null;
      _comparisonResult = null;
    });

    final file = await _photoService.capturePhoto();
    if (file == null) return;

    setState(() {
      _capturedFile = file;
      _isUploading = true;
    });

    try {
      final url = await _photoService.uploadPhoto(
        file: file,
        userId: widget.medication.userId,
        medicationId: widget.medication.id,
        type: type,
      );

      // Update the medication record with the new photo URL
      final reminderService = ref.read(reminderServiceProvider);
      Medication updated;

      switch (type) {
        case PillPhotoType.containerFull:
          updated = widget.medication.copyWith(pillContainerPhotoUrl: url);
          break;
        case PillPhotoType.organizerFilled:
          updated = widget.medication.copyWith(organizerFilledPhotoUrl: url);
          break;
        case PillPhotoType.organizerEmpty:
          updated = widget.medication.copyWith(organizerEmptyPhotoUrl: url);
          break;
        case PillPhotoType.pillCloseUp:
          updated = widget.medication.copyWith(pillCloseUpPhotoUrl: url);
          break;
        case PillPhotoType.verification:
          // For verification photos, compare against reference
          if (widget.medication.pillContainerPhotoUrl != null) {
            final result = await _photoService.comparePhotos(
              referenceUrl: widget.medication.pillContainerPhotoUrl!,
              verificationFile: file,
            );
            setState(() => _comparisonResult = result);
          }
          // Don't update medication record — verification photos go to the log
          setState(() => _isUploading = false);
          return;
      }

      await reminderService.updateMedication(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_labelForType(type)} photo saved!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload failed: $e';
      });
    }
  }

  Future<void> _pickAndUpload(PillPhotoType type) async {
    setState(() {
      _errorMessage = null;
      _capturedFile = null;
      _comparisonResult = null;
    });

    final file = await _photoService.pickFromGallery();
    if (file == null) return;

    setState(() {
      _capturedFile = file;
      _isUploading = true;
    });

    try {
      final url = await _photoService.uploadPhoto(
        file: file,
        userId: widget.medication.userId,
        medicationId: widget.medication.id,
        type: type,
      );

      final reminderService = ref.read(reminderServiceProvider);
      Medication updated;

      switch (type) {
        case PillPhotoType.containerFull:
          updated = widget.medication.copyWith(pillContainerPhotoUrl: url);
          break;
        case PillPhotoType.organizerFilled:
          updated = widget.medication.copyWith(organizerFilledPhotoUrl: url);
          break;
        case PillPhotoType.organizerEmpty:
          updated = widget.medication.copyWith(organizerEmptyPhotoUrl: url);
          break;
        case PillPhotoType.pillCloseUp:
          updated = widget.medication.copyWith(pillCloseUpPhotoUrl: url);
          break;
        case PillPhotoType.verification:
          setState(() => _isUploading = false);
          return;
      }

      await reminderService.updateMedication(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_labelForType(type)} photo saved!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload failed: $e';
      });
    }
  }

  String _labelForType(PillPhotoType type) {
    switch (type) {
      case PillPhotoType.containerFull:
        return 'Pill container';
      case PillPhotoType.organizerFilled:
        return 'Filled organizer';
      case PillPhotoType.organizerEmpty:
        return 'Empty organizer';
      case PillPhotoType.pillCloseUp:
        return 'Pill close-up';
      case PillPhotoType.verification:
        return 'Verification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.medication;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: Text('${med.name} Photos'),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading photo...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Pill Container Reference
                  _buildPhotoSection(
                    title: 'Pill Container',
                    subtitle: 'Reference photo of the full pill bottle or box',
                    icon: Icons.medication,
                    existingUrl: med.pillContainerPhotoUrl,
                    photoType: PillPhotoType.containerFull,
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Pill Close-Up
                  _buildPhotoSection(
                    title: 'Pills / Tablets',
                    subtitle:
                        'Close-up reference photo of the actual medication',
                    icon: Icons.circle,
                    existingUrl: med.pillCloseUpPhotoUrl,
                    photoType: PillPhotoType.pillCloseUp,
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Filled Pill Organizer
                  _buildPhotoSection(
                    title: 'Filled Pill Organizer',
                    subtitle:
                        'Photo of the weekly pillbox after loading medications',
                    icon: Icons.grid_view_rounded,
                    existingUrl: med.organizerFilledPhotoUrl,
                    photoType: PillPhotoType.organizerFilled,
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Empty Organizer
                  _buildPhotoSection(
                    title: 'Empty Organizer Compartment',
                    subtitle:
                        'Photo of an empty compartment confirming pills were taken',
                    icon: Icons.check_box_outline_blank,
                    existingUrl: med.organizerEmptyPhotoUrl,
                    photoType: PillPhotoType.organizerEmpty,
                  ),
                  const SizedBox(height: 20),

                  // Section 5: Verify Now
                  if (med.pillContainerPhotoUrl != null) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Verify Medication',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take a photo now to compare against the reference',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _captureAndUpload(PillPhotoType.verification),
                        icon: const Icon(Icons.verified_user,
                            color: Colors.white),
                        label: const Text(
                          'VERIFY NOW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Comparison result
                  if (_comparisonResult != null) ...[
                    const SizedBox(height: 16),
                    _buildComparisonResult(),
                  ],

                  // Captured preview
                  if (_capturedFile != null && _comparisonResult != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _capturedFile!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
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

  Widget _buildPhotoSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? existingUrl,
    required PillPhotoType photoType,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (existingUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: existingUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 40)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _captureAndUpload(photoType),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(existingUrl != null ? 'Retake' : 'Take Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: const BorderSide(color: AppTheme.primaryOrange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndUpload(photoType),
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonResult() {
    final result = _comparisonResult!;
    final pct = (result.similarityScore * 100).toStringAsFixed(0);
    final color = result.isMatch ? AppTheme.primaryGreen : AppTheme.primaryRed;
    final icon = result.isMatch ? Icons.check_circle : Icons.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isMatch ? 'Match Confirmed' : 'Possible Mismatch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Similarity: $pct%',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (result.notes != null)
                  Text(
                    result.notes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
