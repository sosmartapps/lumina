import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Screen for adding a new patient from the caregiver dashboard
class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleCreatePatient() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final locationService = ref.read(locationServiceProvider);
      final caregiverProvider = ref.read(caregiverNotifierProvider);
      final appState = ref.read(appStateNotifierProvider);

      final caregiverId = caregiverProvider.caregiver?.id;
      if (caregiverId == null) {
        setState(() => _errorMessage = 'Caregiver not loaded');
        return;
      }

      // Geocode address
      final homeLocation = await locationService.getLocationFromAddress(address);
      if (homeLocation == null) {
        setState(() {
          _errorMessage = 'Could not find address. Please try a different format.';
          _isLoading = false;
        });
        return;
      }

      // Create patient
      final user = await authService.createUser(
        name: name,
        phoneNumber: _phoneController.text.trim(),
        primaryCaregiverId: caregiverId,
      );

      // Update with home location
      final updatedUser = user.copyWith(
        homeLocation: homeLocation,
        homeAddress: address,
      );
      await authService.updateUser(updatedUser);

      // Add to provider and auto-select
      caregiverProvider.addManagedUser(updatedUser);
      await appState.setCurrentUserId(updatedUser.id);

      if (!mounted) return;

      // Show success and pop back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updatedUser.name} added successfully'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Add Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Patient',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter details for the person you will care for',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Patient's Name *",
                prefixIcon: Icon(Icons.person),
                hintText: 'e.g., Jack',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Patient's Phone (optional)",
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Home Address *',
                prefixIcon: Icon(Icons.home),
                hintText: '123 Main St, City, State',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The home address will be used for the "Go Home" button',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCreatePatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ADD PATIENT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
