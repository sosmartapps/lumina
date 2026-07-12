import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/quadtrack_provider.dart';
import '../../core/theme/app_theme.dart';
import 'quadtrack_detail_screen.dart';
import 'quadtrack_profile_setup_screen.dart';

/// Registration flow for adding a new QuadTrack device
class QuadTrackRegisterScreen extends ConsumerStatefulWidget {
  final String caregiverId;

  const QuadTrackRegisterScreen({
    super.key,
    required this.caregiverId,
  });

  @override
  ConsumerState<QuadTrackRegisterScreen> createState() =>
      _QuadTrackRegisterScreenState();
}

class _QuadTrackRegisterScreenState
    extends ConsumerState<QuadTrackRegisterScreen> {
  int _currentStep = 0;
  final _serialController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedPatientId;
  String? _validationError;
  bool _isLoading = false;

  /// The caregiver's real linked patients (same source as the rest of the
  /// caregiver dashboard).
  List<AppUser> get _patients =>
      ref.read(caregiverNotifierProvider).managedUsers;

  String _patientNameFor(String? patientId) {
    if (patientId == null) return 'Not selected';
    for (final p in _patients) {
      if (p.id == patientId) return p.name;
    }
    return 'Unknown patient';
  }

  @override
  void dispose() {
    _serialController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _validateSerial() {
    final serial = _serialController.text.trim();

    if (serial.isEmpty) {
      setState(() => _validationError = 'Serial number is required');
      return;
    }

    if (serial.length < 10) {
      setState(() =>
          _validationError = 'Serial number must be at least 10 characters');
      return;
    }

    setState(() => _validationError = null);
  }

  Future<void> _checkSerialExists() async {
    _validateSerial();
    if (_validationError != null) return;

    setState(() => _isLoading = true);

    try {
      final serial = _serialController.text.trim();
      final exists = await ref
          .read(quadTrackServiceProvider)
          .isDeviceRegistered(serial);

      if (mounted) {
        setState(() => _isLoading = false);

        if (exists) {
          setState(() =>
              _validationError = 'This device is already registered');
          return;
        }

        setState(() => _validationError = null);
        _goToNextStep();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _validationError = 'Error checking device: $e';
        });
      }
    }
  }

  void _validateName() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _validationError = 'Device name is required');
      return;
    }

    setState(() => _validationError = null);
  }

  void _goToNextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeRegistration() async {
    if (_selectedPatientId == null) {
      setState(() => _validationError = 'Please select a patient');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final device = await ref.read(quadTrackServiceProvider).registerDevice(
            deviceId: _serialController.text.trim(),
            name: _nameController.text.trim(),
            patientId: _selectedPatientId!,
            caregiverId: widget.caregiverId,
          );

      if (mounted) {
        setState(() => _isLoading = false);

        // Offer missing-person profile setup — it powers the law
        // enforcement share package.
        final setUpProfile = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Set Up Missing-Person Profile?'),
            content: const Text(
              'A profile with a photo, physical description, and medical info lets you instantly share a complete alert package with law enforcement if the patient goes missing. You can also do this later from the device screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Set Up Now'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        // Capture the navigator BEFORE pushReplacement — this State's
        // context is defunct once the route is replaced.
        final navigator = Navigator.of(context);

        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuadTrackDetailScreen(
              deviceId: device.id,
              caregiverId: widget.caregiverId,
            ),
          ),
        );

        if (setUpProfile == true) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => QuadTrackProfileSetupScreen(
                patientId: device.patientId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _validationError = 'Error registering device: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Register QuadTrack Device'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepIndicator(0, 'Serial'),
                  _buildStepConnector(0),
                  _buildStepIndicator(1, 'Name'),
                  _buildStepConnector(1),
                  _buildStepIndicator(2, 'Patient'),
                  _buildStepConnector(2),
                  _buildStepIndicator(3, 'Review'),
                ],
              ),
              const SizedBox(height: 32),

              // Step content
              if (_currentStep == 0) _buildSerialStep(),
              if (_currentStep == 1) _buildNameStep(),
              if (_currentStep == 2) _buildPatientStep(),
              if (_currentStep == 3) _buildReviewStep(),

              // Error message
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryRed),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.primaryRed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryRed,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _isLoading ? null : _goToPreviousStep,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getNextButtonAction(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_currentStep < 3 ? 'Next' : 'Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryTeal : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive ? AppTheme.primaryTeal : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = step < _currentStep;
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? AppTheme.primaryTeal : Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildSerialStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Serial Number',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the serial number from the QuadTrack hardware label',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _serialController,
          decoration: InputDecoration(
            labelText: 'Serial Number',
            hintText: 'e.g., QT-2024-001ABC',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        Text(
          'The serial number is unique to your QuadTrack device and helps prevent duplicate registration.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Name',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Give your device a friendly name',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Device Name',
            hintText: 'e.g., Mom\'s Tracker',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),
        Text(
          'Examples: "Mom\'s Phone", "Dad\'s Tracker", "Home Device"',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  Widget _buildPatientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Patient',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose which patient this device will track',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: ref.read(caregiverNotifierProvider),
          builder: (context, _) {
            final patients = _patients;
            if (patients.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryRed),
                ),
                child: Text(
                  'No linked patients found. Add a patient from the caregiver dashboard before registering a device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryRed,
                      ),
                ),
              );
            }
            return DropdownButtonFormField<String>(
              initialValue: _selectedPatientId,
              decoration: InputDecoration(
                labelText: 'Patient',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: patients
                  .map((patient) => DropdownMenuItem(
                        value: patient.id,
                        child: Text(
                          patient.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _selectedPatientId = value);
                      _validateName();
                    },
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'You can add more patients or change this assignment later.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Register',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReviewRow('Serial Number', _serialController.text.trim()),
                const Divider(),
                _buildReviewRow('Device Name', _nameController.text.trim()),
                const Divider(),
                _buildReviewRow(
                  'Patient',
                  _patientNameFor(_selectedPatientId),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryGreen),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once registered, this device will begin tracking location and battery status.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getNextButtonAction() {
    if (_isLoading) return null;

    switch (_currentStep) {
      case 0:
        return _checkSerialExists;
      case 1:
        return () {
          _validateName();
          if (_validationError == null) {
            _goToNextStep();
          }
        };
      case 2:
        return () {
          if (_selectedPatientId != null) {
            _goToNextStep();
          } else {
            setState(
              () => _validationError = 'Please select a patient',
            );
          }
        };
      case 3:
        return _completeRegistration;
      default:
        return null;
    }
  }
}
