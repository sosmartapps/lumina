import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import 'package:lumina/core/theme/app_theme.dart';
import 'package:lumina/core/models/user_profile.dart';

/// Multi-step profile setup for QuadTrack
class QuadTrackProfileSetupScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String? initialUserProfileId;

  const QuadTrackProfileSetupScreen({
    super.key,
    required this.patientId,
    this.initialUserProfileId,
  });

  @override
  ConsumerState<QuadTrackProfileSetupScreen> createState() =>
      _QuadTrackProfileSetupScreenState();
}

class _QuadTrackProfileSetupScreenState
    extends ConsumerState<QuadTrackProfileSetupScreen> {
  late PageController _pageController;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _photoUrl;
  File? _photoFile;

  // Step 1: Identity & Photo
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _preferredNameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;

  // Step 2: Physical Description
  double? _heightCm;
  double? _weightKg;
  String? _hairColor;
  String? _eyeColor;
  String? _race;
  String? _buildType;
  final _marksController = TextEditingController();
  final _clothingController = TextEditingController();
  String? _glasses;
  String? _mobilityAids;

  // Step 3: Medical
  final _diagnosisController = TextEditingController();
  String? _cognitiveStatus;
  final _medicalAlertController = TextEditingController();
  final _behaviorController = TextEditingController();
  final _communicationController = TextEditingController();
  final _calmingController = TextEditingController();
  final _triggersController = TextEditingController();

  // Step 4: Vehicle
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  String? _vehicleState;
  final _vehicleVinController = TextEditingController();
  final _vehicleNotesController = TextEditingController();
  bool _hasVehicle = true;

  // Step 5: Address & Review
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  String? _state;
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();

  static const List<String> _genders = ['Male', 'Female', 'Non-binary', 'Other'];
  static const List<String> _races = [
    'White',
    'Black/African American',
    'Hispanic/Latino',
    'Asian',
    'Native American',
    'Pacific Islander',
    'Multi-racial',
    'Other'
  ];
  static const List<String> _builds = ['Slim', 'Average', 'Heavy', 'Muscular', 'Athletic'];
  static const List<String> _hairColors = [
    'Black',
    'Brown',
    'Blonde',
    'Red',
    'Gray',
    'White',
    'Bald'
  ];
  static const List<String> _eyeColors = ['Blue', 'Brown', 'Green', 'Hazel', 'Gray', 'Other'];
  static const List<String> _cognitiveStatuses = [
    'Fully aware',
    'Mild cognitive impairment',
    'Moderate cognitive impairment',
    'Severe cognitive impairment',
    'Non-verbal'
  ];
  static const List<String> _glasseTypes = ['None', 'Reading glasses', 'Prescription', 'Always wears'];
  static const List<String> _mobilityTypes = [
    'None',
    'Cane',
    'Walker',
    'Wheelchair',
    'Crutches',
    'Other'
  ];
  static const List<String> _states = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _countryController.text = 'USA';
    _state = 'AZ';
    _vehicleState = 'AZ';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _preferredNameController.dispose();
    _marksController.dispose();
    _clothingController.dispose();
    _diagnosisController.dispose();
    _medicalAlertController.dispose();
    _behaviorController.dispose();
    _communicationController.dispose();
    _calmingController.dispose();
    _triggersController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _vehicleVinController.dispose();
    _vehicleNotesController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _photoFile = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photo: $e')),
      );
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_photoFile == null) return null;

    try {
      final fileName = '${widget.patientId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('user_profiles/$fileName');
      await ref.putFile(_photoFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      String? photoUrl = _photoUrl;
      if (_photoFile != null) {
        photoUrl = await _uploadPhoto();
      }

      final userProfile = UserProfile(
        id: widget.initialUserProfileId ?? 'profile_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.patientId,
        legalFirstName: _firstNameController.text.isNotEmpty
            ? _firstNameController.text
            : null,
        legalMiddleName: _middleNameController.text.isNotEmpty
            ? _middleNameController.text
            : null,
        legalLastName: _lastNameController.text.isNotEmpty
            ? _lastNameController.text
            : null,
        preferredName: _preferredNameController.text.isNotEmpty
            ? _preferredNameController.text
            : null,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        heightCm: _heightCm,
        weightKg: _weightKg,
        hairColor: _hairColor,
        eyeColor: _eyeColor,
        race: _race,
        buildType: _buildType,
        distinguishingMarks: _marksController.text.isNotEmpty
            ? _marksController.text
            : null,
        usualClothing: _clothingController.text.isNotEmpty
            ? _clothingController.text
            : null,
        glasses: _glasses,
        mobilityAids: _mobilityAids,
        streetAddress: _streetController.text.isNotEmpty
            ? _streetController.text
            : null,
        city: _cityController.text.isNotEmpty ? _cityController.text : null,
        state: _state,
        zipCode: _zipController.text.isNotEmpty ? _zipController.text : null,
        country: _countryController.text.isNotEmpty
            ? _countryController.text
            : null,
        primaryDiagnosis: _diagnosisController.text.isNotEmpty
            ? _diagnosisController.text
            : null,
        cognitiveStatus: _cognitiveStatus,
        medicalAlertInfo: _medicalAlertController.text.isNotEmpty
            ? _medicalAlertController.text
            : null,
        behaviorWhenLost: _behaviorController.text.isNotEmpty
            ? _behaviorController.text
            : null,
        communicationAbility: _communicationController.text.isNotEmpty
            ? _communicationController.text
            : null,
        calmingTechniques: _calmingController.text.isNotEmpty
            ? _calmingController.text
            : null,
        triggersToAvoid: _triggersController.text.isNotEmpty
            ? _triggersController.text
            : null,
        vehicleMake: _vehicleMakeController.text.isNotEmpty
            ? _vehicleMakeController.text
            : null,
        vehicleModel: _vehicleModelController.text.isNotEmpty
            ? _vehicleModelController.text
            : null,
        vehicleYear: _vehicleYearController.text.isNotEmpty
            ? int.tryParse(_vehicleYearController.text)
            : null,
        vehicleColor: _vehicleColorController.text.isNotEmpty
            ? _vehicleColorController.text
            : null,
        vehicleLicensePlate: _vehiclePlateController.text.isNotEmpty
            ? _vehiclePlateController.text
            : null,
        vehicleLicenseState: _vehicleState,
        vehicleVin: _vehicleVinController.text.isNotEmpty
            ? _vehicleVinController.text
            : null,
        vehicleNotes: _vehicleNotesController.text.isNotEmpty
            ? _vehicleNotesController.text
            : null,
        photos: photoUrl != null
            ? [
                UserPhoto(
                  id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
                  url: photoUrl,
                  dateTaken: DateTime.now(),
                  isPrimary: true,
                )
              ]
            : [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(userProfile.id)
          .set(userProfile.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('QuadTrack Profile Setup'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Step Indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final isActive = index <= _currentStep;
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppTheme.primaryTeal : AppTheme.textSecondaryLight,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ['Identity', 'Physical', 'Medical', 'Vehicle', 'Review'][index],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                );
              }),
            ),
          ),
          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _buildStep1Identity(),
                _buildStep2Physical(),
                _buildStep3Medical(),
                _buildStep4Vehicle(),
                _buildStep5Review(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                ),
                child: Text(_currentStep == 4 ? 'Save Profile' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity & Photo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                child: _photoFile == null
                    ? const Icon(Icons.camera_alt, size: 40)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera),
              label: const Text('Take Photo'),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'Legal First Name *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _middleNameController,
            decoration: InputDecoration(
              labelText: 'Middle Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Legal Last Name *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _preferredNameController,
            decoration: InputDecoration(
              labelText: 'Preferred Name (what they respond to)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _dateOfBirth = picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _dateOfBirth != null
                    ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!)
                    : 'Tap to select',
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _gender = v),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Physical() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Physical Description',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              labelText: 'Height (cm)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _heightCm = double.tryParse(v)),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _weightKg = double.tryParse(v)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _hairColor,
            decoration: InputDecoration(
              labelText: 'Hair Color',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _hairColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _hairColor = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _eyeColor,
            decoration: InputDecoration(
              labelText: 'Eye Color',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _eyeColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _eyeColor = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _race,
            decoration: InputDecoration(
              labelText: 'Race/Ethnicity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _races.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _race = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _buildType,
            decoration: InputDecoration(
              labelText: 'Build Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _builds.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setState(() => _buildType = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _marksController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Distinguishing Marks (scars, tattoos, birthmarks)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clothingController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Usually Wears (clothing preferences)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _glasses,
            decoration: InputDecoration(
              labelText: 'Glasses',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _glasseTypes.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _glasses = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mobilityAids,
            decoration: InputDecoration(
              labelText: 'Mobility Aids',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _mobilityTypes
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _mobilityAids = v),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Medical() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _diagnosisController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Primary Diagnosis (e.g., Alzheimer\'s, Autism)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cognitiveStatus,
            decoration: InputDecoration(
              labelText: 'Cognitive Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: _cognitiveStatuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _cognitiveStatus = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicalAlertController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Medical Alert (critical info for first responders)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _behaviorController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Behavior When Lost',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _communicationController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Communication Ability',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calmingController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Calming Techniques (what helps them relax)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _triggersController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Triggers to Avoid (what upsets them)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Vehicle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _hasVehicle,
            onChanged: (v) => setState(() => _hasVehicle = v ?? true),
            title: const Text('Person has access to a vehicle'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasVehicle) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _vehicleMakeController,
              decoration: InputDecoration(
                labelText: 'Vehicle Make (e.g., Toyota)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleModelController,
              decoration: InputDecoration(
                labelText: 'Vehicle Model (e.g., Camry)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleYearController,
              decoration: InputDecoration(
                labelText: 'Vehicle Year (e.g., 2020)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleColorController,
              decoration: InputDecoration(
                labelText: 'Vehicle Color (e.g., Silver)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehiclePlateController,
              decoration: InputDecoration(
                labelText: 'License Plate (e.g., ABC1234)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehicleState,
              decoration: InputDecoration(
                labelText: 'License Plate State',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _vehicleState = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleVinController,
              decoration: InputDecoration(
                labelText: 'VIN (Vehicle Identification Number)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleNotesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Vehicle Notes (damages, stickers, etc.)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep5Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewSection('Identity', [
                    '${_firstNameController.text} ${_lastNameController.text}',
                    if (_preferredNameController.text.isNotEmpty)
                      'Responds to: ${_preferredNameController.text}',
                    if (_dateOfBirth != null)
                      'DOB: ${DateFormat('MMM dd, yyyy').format(_dateOfBirth!)}',
                    if (_gender != null) 'Gender: $_gender',
                  ]),
                  const Divider(),
                  _buildReviewSection('Physical', [
                    if (_heightCm != null && _weightKg != null)
                      '${(_heightCm! / 2.54 / 12).floor()}\'${((_heightCm! / 2.54) % 12).round()}" / ${(_weightKg! * 2.205).toStringAsFixed(0)} lbs',
                    if (_hairColor != null || _eyeColor != null)
                      'Hair: $_hairColor, Eyes: $_eyeColor',
                    if (_race != null) 'Race: $_race',
                    if (_buildType != null) 'Build: $_buildType',
                    if (_marksController.text.isNotEmpty)
                      'Marks: ${_marksController.text}',
                    if (_glasses != null) 'Glasses: $_glasses',
                    if (_mobilityAids != null) 'Mobility: $_mobilityAids',
                  ]),
                  const Divider(),
                  _buildReviewSection('Medical', [
                    if (_diagnosisController.text.isNotEmpty)
                      'Diagnosis: ${_diagnosisController.text}',
                    if (_cognitiveStatus != null) 'Cognitive: $_cognitiveStatus',
                    if (_behaviorController.text.isNotEmpty)
                      'Behavior: ${_behaviorController.text}',
                  ]),
                  if (_hasVehicle) ...[
                    const Divider(),
                    _buildReviewSection('Vehicle', [
                      if (_vehicleMakeController.text.isNotEmpty)
                        '${_vehicleYearController.text} ${_vehicleMakeController.text} ${_vehicleModelController.text}',
                      if (_vehiclePlateController.text.isNotEmpty)
                        'Plate: ${_vehiclePlateController.text} ($_vehicleState)',
                      if (_vehicleColorController.text.isNotEmpty)
                        'Color: ${_vehicleColorController.text}',
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'All information will be stored securely and used only for missing person alerts.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    final filteredItems = items.where((item) => item.isNotEmpty).toList();
    if (filteredItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...filteredItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(item, style: Theme.of(context).textTheme.bodySmall),
        )),
      ],
    );
  }
}
