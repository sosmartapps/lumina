import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/services/missing_person_flyer_service.dart';
import '../../core/utils/units.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeneratingReport = false;
  bool _isGeneratingFlyer = false;

  // Form controllers for Identity tab
  final _legalFirstNameController = TextEditingController();
  final _legalMiddleNameController = TextEditingController();
  final _legalLastNameController = TextEditingController();
  final _preferredNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  // App display identity (users/{id}.name + phoneNumber — what the home
  // screen greeting, notifications, and caregiver lists show)
  final _displayNameController = TextEditingController();
  final _userPhoneController = TextEditingController();
  // Imperial entry (converted to metric for storage)
  final _heightFtController = TextEditingController();
  final _heightInController = TextEditingController();
  UnitsSystem _units = Units.resolve(null);
  DateTime? _dateOfBirth;
  String? _gender;

  // Form controllers for Physical Description tab
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _hairColor;
  String? _eyeColor;
  String? _race;
  String? _skinTone;
  String? _buildType;
  final _distinguishingMarksController = TextEditingController();
  final _usualClothingController = TextEditingController();
  String? _glasses;
  final _mobilityAidsController = TextEditingController();

  // Form controllers for Address tab
  final _streetAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Form controllers for Documents tab
  final _driversLicenseNumberController = TextEditingController();
  final _driversLicenseStateController = TextEditingController();
  DateTime? _driversLicenseExpiration;
  final _ssnLast4Controller = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _medicareNumberController = TextEditingController();
  final _medicaidNumberController = TextEditingController();

  // Form controllers for Medical Alert tab
  final _primaryDiagnosisController = TextEditingController();
  final _cognitiveStatusController = TextEditingController();
  final _wanderingHistoryController = TextEditingController();
  final _communicationAbilityController = TextEditingController();
  final _behaviorWhenLostController = TextEditingController();
  final _medicalAlertInfoController = TextEditingController();
  final _responseToNameController = TextEditingController();
  final _responseToStrangersController = TextEditingController();
  final _calmingTechniquesController = TextEditingController();
  final _triggersToAvoidController = TextEditingController();

  /// True when any field changed since the last successful save —
  /// guards against silent data loss on back-navigation (2026-07-08).
  bool _dirty = false;

  /// Debounced auto-save: fires 2.5s after the user stops typing.
  Timer? _autoSaveTimer;
  bool _autoSaveFailed = false;

  void _wireDirtyTracking() {
    for (final c in [
      _legalFirstNameController,
      _legalMiddleNameController,
      _legalLastNameController,
      _preferredNameController,
      _nicknameController,
      _displayNameController,
      _userPhoneController,
      _heightController,
      _weightController,
      _heightFtController,
      _heightInController,
    ]) {
      c.addListener(() {
        if (!mounted) return;
        if (!_dirty) setState(() => _dirty = true);
        _autoSaveTimer?.cancel();
        _autoSaveTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _dirty && !_isSaving) _saveProfile(auto: true);
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Wire AFTER first frame so programmatic loads don't mark dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _wireDirtyTracking();
      });
    });
    _tabController = TabController(length: 8, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _legalFirstNameController.dispose();
    _legalMiddleNameController.dispose();
    _legalLastNameController.dispose();
    _preferredNameController.dispose();
    _nicknameController.dispose();
    _displayNameController.dispose();
    _userPhoneController.dispose();
    _autoSaveTimer?.cancel();
    _heightFtController.dispose();
    _heightInController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _distinguishingMarksController.dispose();
    _usualClothingController.dispose();
    _mobilityAidsController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _driversLicenseNumberController.dispose();
    _driversLicenseStateController.dispose();
    _ssnLast4Controller.dispose();
    _passportNumberController.dispose();
    _medicareNumberController.dispose();
    _medicaidNumberController.dispose();
    _primaryDiagnosisController.dispose();
    _cognitiveStatusController.dispose();
    _wanderingHistoryController.dispose();
    _communicationAbilityController.dispose();
    _behaviorWhenLostController.dispose();
    _medicalAlertInfoController.dispose();
    _responseToNameController.dispose();
    _responseToStrangersController.dispose();
    _calmingTechniquesController.dispose();
    _triggersToAvoidController.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserProfileService.getUserProfile(widget.userId);
      if (profile != null) {
        _populateControllers(profile);
      }
      // Core app identity from the users doc (editable here since 2026-07-07)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        _displayNameController.text = userData['name'] ?? '';
        _userPhoneController.text = userData['phoneNumber'] ?? '';
        final settings = userData['settings'] as Map<String, dynamic>?;
        _units = Units.resolve(settings?['units'] as String?);
        _syncImperialControllers();
      }
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  /// Fill ft/in and lb fields from the metric values.
  void _syncImperialControllers() {
    if (_units != UnitsSystem.imperial) return;
    final cm = double.tryParse(_heightController.text);
    if (cm != null) {
      final h = Units.cmToFeetInches(cm);
      _heightFtController.text = h.feet.toString();
      _heightInController.text = h.inches.toString();
    }
    final kg = double.tryParse(_weightController.text);
    if (kg != null) {
      _weightController.text = Units.kgToLb(kg).round().toString();
    }
  }

  void _populateControllers(UserProfile profile) {
    // Identity
    _legalFirstNameController.text = profile.legalFirstName ?? '';
    _legalMiddleNameController.text = profile.legalMiddleName ?? '';
    _legalLastNameController.text = profile.legalLastName ?? '';
    _preferredNameController.text = profile.preferredName ?? '';
    _nicknameController.text = profile.nickname ?? '';
    _dateOfBirth = profile.dateOfBirth;
    _gender = profile.gender;

    // Physical Description
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _hairColor = profile.hairColor;
    _eyeColor = profile.eyeColor;
    _race = profile.race;
    _skinTone = profile.skinTone;
    _buildType = profile.buildType;
    _distinguishingMarksController.text = profile.distinguishingMarks ?? '';
    _usualClothingController.text = profile.usualClothing ?? '';
    _glasses = profile.glasses;
    _mobilityAidsController.text = profile.mobilityAids ?? '';

    // Address
    _streetAddressController.text = profile.streetAddress ?? '';
    _cityController.text = profile.city ?? '';
    _stateController.text = profile.state ?? '';
    _zipCodeController.text = profile.zipCode ?? '';
    _countryController.text = profile.country ?? '';

    // Documents
    _driversLicenseNumberController.text = profile.driversLicenseNumber ?? '';
    _driversLicenseStateController.text = profile.driversLicenseState ?? '';
    _driversLicenseExpiration = profile.driversLicenseExpiration;
    _ssnLast4Controller.text = profile.ssnLast4 ?? '';
    _passportNumberController.text = profile.passportNumber ?? '';
    _medicareNumberController.text = profile.medicareNumber ?? '';
    _medicaidNumberController.text = profile.medicaidNumber ?? '';

    // Medical Alert
    _primaryDiagnosisController.text = profile.primaryDiagnosis ?? '';
    _cognitiveStatusController.text = profile.cognitiveStatus ?? '';
    _wanderingHistoryController.text = profile.wanderingHistory ?? '';
    _communicationAbilityController.text = profile.communicationAbility ?? '';
    _behaviorWhenLostController.text = profile.behaviorWhenLost ?? '';
    _medicalAlertInfoController.text = profile.medicalAlertInfo ?? '';
    _responseToNameController.text = profile.responseToName ?? '';
    _responseToStrangersController.text = profile.responseToStrangers ?? '';
    _calmingTechniquesController.text = profile.calmingTechniques ?? '';
    _triggersToAvoidController.text = profile.triggersToAvoid ?? '';
  }

  Future<void> _saveProfile({bool auto = false}) async {
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final updatedProfile = UserProfile(
        id: _profile?.id ?? '',
        userId: widget.userId,
        legalFirstName: _legalFirstNameController.text.isEmpty
            ? null
            : _legalFirstNameController.text,
        legalMiddleName: _legalMiddleNameController.text.isEmpty
            ? null
            : _legalMiddleNameController.text,
        legalLastName: _legalLastNameController.text.isEmpty
            ? null
            : _legalLastNameController.text,
        preferredName: _preferredNameController.text.isEmpty
            ? null
            : _preferredNameController.text,
        nickname:
            _nicknameController.text.isEmpty ? null : _nicknameController.text,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        heightCm: _units == UnitsSystem.imperial
            ? ((_heightFtController.text.isNotEmpty ||
                    _heightInController.text.isNotEmpty)
                ? Units.feetInchesToCm(
                    int.tryParse(_heightFtController.text) ?? 0,
                    int.tryParse(_heightInController.text) ?? 0)
                : null)
            : double.tryParse(_heightController.text),
        weightKg: _units == UnitsSystem.imperial
            ? (double.tryParse(_weightController.text) != null
                ? Units.lbToKg(double.parse(_weightController.text))
                : null)
            : double.tryParse(_weightController.text),
        hairColor: _hairColor,
        eyeColor: _eyeColor,
        race: _race,
        skinTone: _skinTone,
        buildType: _buildType,
        distinguishingMarks: _distinguishingMarksController.text.isEmpty
            ? null
            : _distinguishingMarksController.text,
        usualClothing: _usualClothingController.text.isEmpty
            ? null
            : _usualClothingController.text,
        glasses: _glasses,
        mobilityAids: _mobilityAidsController.text.isEmpty
            ? null
            : _mobilityAidsController.text,
        streetAddress: _streetAddressController.text.isEmpty
            ? null
            : _streetAddressController.text,
        city: _cityController.text.isEmpty ? null : _cityController.text,
        state: _stateController.text.isEmpty ? null : _stateController.text,
        zipCode:
            _zipCodeController.text.isEmpty ? null : _zipCodeController.text,
        country:
            _countryController.text.isEmpty ? null : _countryController.text,
        driversLicenseNumber: _driversLicenseNumberController.text.isEmpty
            ? null
            : _driversLicenseNumberController.text,
        driversLicenseState: _driversLicenseStateController.text.isEmpty
            ? null
            : _driversLicenseStateController.text,
        driversLicenseExpiration: _driversLicenseExpiration,
        ssnLast4:
            _ssnLast4Controller.text.isEmpty ? null : _ssnLast4Controller.text,
        passportNumber: _passportNumberController.text.isEmpty
            ? null
            : _passportNumberController.text,
        medicareNumber: _medicareNumberController.text.isEmpty
            ? null
            : _medicareNumberController.text,
        medicaidNumber: _medicaidNumberController.text.isEmpty
            ? null
            : _medicaidNumberController.text,
        primaryDiagnosis: _primaryDiagnosisController.text.isEmpty
            ? null
            : _primaryDiagnosisController.text,
        cognitiveStatus: _cognitiveStatusController.text.isEmpty
            ? null
            : _cognitiveStatusController.text,
        wanderingHistory: _wanderingHistoryController.text.isEmpty
            ? null
            : _wanderingHistoryController.text,
        communicationAbility: _communicationAbilityController.text.isEmpty
            ? null
            : _communicationAbilityController.text,
        behaviorWhenLost: _behaviorWhenLostController.text.isEmpty
            ? null
            : _behaviorWhenLostController.text,
        medicalAlertInfo: _medicalAlertInfoController.text.isEmpty
            ? null
            : _medicalAlertInfoController.text,
        photos: _profile?.photos ?? [],
        frequentPlaces: _profile?.frequentPlaces ?? [],
        // Preserve structured vehicles + social links across text auto-saves
        // (this builder recreates the profile from scratch; omitting these
        // would wipe them via the merge-set write).
        vehicles: _profile?.vehicles ?? [],
        socialMediaLinks: _profile?.socialMediaLinks ?? [],
        responseToName: _responseToNameController.text.isEmpty
            ? null
            : _responseToNameController.text,
        responseToStrangers: _responseToStrangersController.text.isEmpty
            ? null
            : _responseToStrangersController.text,
        calmingTechniques: _calmingTechniquesController.text.isEmpty
            ? null
            : _calmingTechniquesController.text,
        triggersToAvoid: _triggersToAvoidController.text.isEmpty
            ? null
            : _triggersToAvoidController.text,
        createdAt: _profile?.createdAt ?? now,
        updatedAt: now,
      );

      await UserProfileService.saveUserProfile(widget.userId, updatedProfile);

      // Sync core identity to AppUser (greeting, notifications, lists)
      final newPreferred = _preferredNameController.text.trim();
      final newDisplayName = _displayNameController.text.trim();
      final newPhone = _userPhoneController.text.trim();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'preferredName': newPreferred.isEmpty ? null : newPreferred,
        if (newDisplayName.isNotEmpty) 'name': newDisplayName,
        'phoneNumber': newPhone.isEmpty ? null : newPhone,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
        _dirty = false;
        _autoSaveFailed = false;
      });

      if (mounted && !auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        if (auto) _autoSaveFailed = true;
      });
      if (auto) return; // banner shows; manual save gives the full dialog
      if (mounted) {
        // BLOCKING dialog — a snackbar was missable and typed data was
        // lost when the user navigated away after a failed save.
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.error, color: Colors.red, size: 40),
            title: const Text('NOT saved'),
            content: Text(
                'Your entries are still on this screen — do not leave '
                'without saving.\n\nError: $e'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      // Show photo type selection
      final photoType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Face (Front)'),
                onTap: () => Navigator.pop(context, 'face'),
              ),
              ListTile(
                title: const Text('Full Body'),
                onTap: () => Navigator.pop(context, 'full_body'),
              ),
              ListTile(
                title: const Text('Profile (Side)'),
                onTap: () => Navigator.pop(context, 'profile'),
              ),
            ],
          ),
        ),
      );

      if (photoType == null) return;

      if (!mounted) return;

      // Show description dialog
      final descriptionController = TextEditingController();
      final description = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Description'),
          content: TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              hintText: 'e.g., "With glasses, gray hair"',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, descriptionController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      // Upload photo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );
      }

      final imageBytes = await File(image.path).readAsBytes();
      final photo = await UserProfileService.uploadPhoto(
        widget.userId,
        imageBytes,
        photoType: photoType,
        description: description,
        isPrimary: _profile?.photos.isEmpty ?? true,
      );

      if (photo == null) {
        throw Exception('Failed to upload photo');
      }

      // Update profile with new photo
      final updatedPhotos = <UserPhoto>[...(_profile?.photos ?? []), photo];
      final updatedProfile = _profile?.copyWith(photos: updatedPhotos) ??
          UserProfile(
            id: '',
            userId: widget.userId,
            photos: updatedPhotos,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      await UserProfileService.saveUserProfile(widget.userId, updatedProfile);

      setState(() {
        _profile = updatedProfile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding photo: $e')),
        );
      }
    }
  }

  Future<void> _deletePhoto(UserPhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await UserProfileService.deletePhoto(widget.userId, photo.id);

      final updatedPhotos =
          _profile?.photos.where((p) => p.id != photo.id).toList() ?? [];
      final updatedProfile = _profile?.copyWith(photos: updatedPhotos);

      if (updatedProfile != null) {
        await UserProfileService.saveUserProfile(widget.userId, updatedProfile);
        setState(() {
          _profile = updatedProfile;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e')),
        );
      }
    }
  }

  Future<void> _setAsPrimary(UserPhoto photo) async {
    try {
      final updatedPhotos = _profile?.photos.map((p) {
            return UserPhoto(
              id: p.id,
              url: p.url,
              thumbnailUrl: p.thumbnailUrl,
              dateTaken: p.dateTaken,
              description: p.description,
              photoType: p.photoType,
              isPrimary: p.id == photo.id,
            );
          }).toList() ??
          [];

      final updatedProfile = _profile?.copyWith(photos: updatedPhotos);

      if (updatedProfile != null) {
        await UserProfileService.saveUserProfile(widget.userId, updatedProfile);
        setState(() {
          _profile = updatedProfile;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primary photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating primary photo: $e')),
        );
      }
    }
  }

  Future<void> _generateLostPersonReport() async {
    setState(() => _isGeneratingReport = true);

    try {
      final report =
          await UserProfileService.generateLostPersonReport(widget.userId);
      final reportText = UserProfileService.formatLostPersonReportAsText(report);

      setState(() => _isGeneratingReport = false);

      if (!mounted) return;

      // Show preview and share options
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Lost Person Report'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Text(
                reportText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                SharePlus.instance.share(
                  ShareParams(
                    text: reportText,
                    subject:
                        'MISSING PERSON: ${report.userName} - ${DateFormat('MMM d, yyyy h:mm a').format(report.generatedAt)}',
                  ),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isGeneratingReport = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved changes'),
            content: const Text(
                'You have unsaved changes. Leave without saving?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else if (!_dirty && !_autoSaveFailed)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Tooltip(
                message: 'All changes saved',
                child: Icon(Icons.check_circle, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save,
                  color: _autoSaveFailed ? Colors.red.shade200 : Colors.white),
              onPressed: _saveProfile,
              tooltip: 'Save Profile',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Identity'),
            Tab(icon: Icon(Icons.accessibility), text: 'Physical'),
            Tab(icon: Icon(Icons.home), text: 'Address'),
            Tab(icon: Icon(Icons.badge), text: 'Documents'),
            Tab(icon: Icon(Icons.medical_information), text: 'Medical Alert'),
            Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
            Tab(icon: Icon(Icons.directions_car), text: 'Vehicles'),
            Tab(icon: Icon(Icons.share), text: 'Social Media'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_autoSaveFailed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Colors.red,
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Changes NOT saved — check connection',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: _saveProfile,
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                // Lost Person Report Banner — sentence full-width on top,
                // compact button below (side-by-side crushed the text).
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.red.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'In an emergency, generate a Lost Person Report '
                              'to share with authorities.',
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingReport
                              ? null
                              : _generateLostPersonReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          icon: _isGeneratingReport
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.description, size: 18),
                          label: const Text('Generate Lost Person Report'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isGeneratingFlyer ? null : _generateFlyer,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade700),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          icon: _isGeneratingFlyer
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red.shade700,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Missing Person Flyer (PDF)'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIdentityTab(),
                      _buildPhysicalTab(),
                      _buildAddressTab(),
                      _buildDocumentsTab(),
                      _buildMedicalAlertTab(),
                      _buildPhotosTab(),
                      _buildVehiclesTab(),
                      _buildSocialMediaTab(),
                    ],
                  ),
                ),
              ],
            ),
    ),
    );
  }

  Widget _buildIdentityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Legal Name'),
          TextFormField(
            controller: _legalFirstNameController,
            decoration: const InputDecoration(
              labelText: 'Legal First Name *',
              hintText: 'As shown on ID',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _legalMiddleNameController,
            decoration: const InputDecoration(
              labelText: 'Legal Middle Name',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _legalLastNameController,
            decoration: const InputDecoration(
              labelText: 'Legal Last Name *',
              hintText: 'As shown on ID',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Preferred Names'),
          TextFormField(
            controller: _preferredNameController,
            decoration: const InputDecoration(
              labelText: 'Preferred Name',
              hintText: 'What they respond to',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'Family nickname, etc.',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('App Display'),
          TextFormField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display Name *',
              hintText: 'Shown on the home screen and to caregivers',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "User's Phone",
              hintText: 'The phone this person carries',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Personal Information'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of Birth'),
            subtitle: Text(_dateOfBirth != null
                ? DateFormat('MMMM d, yyyy').format(_dateOfBirth!)
                : 'Not set'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1950),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _dateOfBirth = date);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
                  isExpanded: true,
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: ['Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (value) => setState(() => _gender = value),
          ),
          if (_dateOfBirth != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: Colors.purple),
                    const SizedBox(width: 12),
                    Text(
                      'Age: ${_profile?.age ?? _calculateAge(_dateOfBirth!)} years old',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Widget _buildPhysicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Measurements'),
          if (_units == UnitsSystem.imperial)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightFtController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Height (ft)',
                      hintText: '5',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightInController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '(in)',
                      hintText: '11',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight (lb)',
                      hintText: '165',
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      hintText: 'e.g., 170',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'e.g., 75',
                    ),
                  ),
                ),
              ],
            ),
          if (_heightController.text.isNotEmpty ||
              _weightController.text.isNotEmpty ||
              _heightFtController.text.isNotEmpty ||
              _heightInController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _buildMeasurementSummary(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('Appearance'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _hairColor,
                  decoration: const InputDecoration(labelText: 'Hair Color'),
                  items: [
                    'Black',
                    'Brown',
                    'Blonde',
                    'Red',
                    'Gray',
                    'White',
                    'Bald',
                    'Other'
                  ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (value) => setState(() => _hairColor = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _eyeColor,
                  decoration: const InputDecoration(labelText: 'Eye Color'),
                  items: ['Brown', 'Blue', 'Green', 'Hazel', 'Gray', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _eyeColor = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _race,
                  decoration: const InputDecoration(labelText: 'Race/Ethnicity'),
                  items: [
                    'White',
                    'Black/African American',
                    'Hispanic/Latino',
                    'Asian',
                    'Native American',
                    'Pacific Islander',
                    'Middle Eastern',
                    'Mixed',
                    'Other'
                  ].map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (value) => setState(() => _race = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _skinTone,
                  decoration: const InputDecoration(labelText: 'Skin Tone'),
                  items: ['Very Light', 'Light', 'Medium', 'Olive', 'Brown', 'Dark']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _skinTone = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
                  isExpanded: true,
            initialValue: _buildType,
            decoration: const InputDecoration(labelText: 'Build Type'),
            items: ['Slim', 'Average', 'Athletic', 'Heavy', 'Stocky']
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (value) => setState(() => _buildType = value),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Distinguishing Features'),
          TextFormField(
            controller: _distinguishingMarksController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Distinguishing Marks',
              hintText: 'Scars, tattoos, birthmarks, etc.',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usualClothingController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Usual Clothing',
              hintText: 'What they typically wear',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
                  isExpanded: true,
            initialValue: _glasses,
            decoration: const InputDecoration(labelText: 'Glasses'),
            items: [
              'None',
              'Always wears',
              'Reading glasses only',
              'Sunglasses',
              'Contact lenses'
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (value) => setState(() => _glasses = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mobilityAidsController,
            decoration: const InputDecoration(
              labelText: 'Mobility Aids',
              hintText: 'Walker, cane, wheelchair, etc.',
            ),
          ),
        ],
      ),
    );
  }

  String _buildMeasurementSummary() {
    final parts = <String>[];

    if (_units == UnitsSystem.imperial) {
      // Fields hold ft/in and lb; show the metric equivalent.
      final ft = int.tryParse(_heightFtController.text);
      final inches = int.tryParse(_heightInController.text);
      if (ft != null || inches != null) {
        final cm = Units.feetInchesToCm(ft ?? 0, inches ?? 0);
        parts.add("${ft ?? 0}'${inches ?? 0}\" (${cm.round()} cm)");
      }
      final lb = double.tryParse(_weightController.text);
      if (lb != null) {
        parts.add('${lb.round()} lb (${Units.lbToKg(lb).round()} kg)');
      }
    } else {
      final height = double.tryParse(_heightController.text);
      final weight = double.tryParse(_weightController.text);
      if (height != null) {
        parts.add(
            '${Units.formatHeight(height, UnitsSystem.imperial)} (${height.round()} cm)');
      }
      if (weight != null) {
        parts.add(
            '${Units.formatWeight(weight, UnitsSystem.imperial)} (${weight.round()} kg)');
      }
    }

    return parts.join(' • ');
  }

  Widget _buildAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Home Address'),
          const SizedBox(height: 8),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This address will be used in the Lost Person Report and for "Navigate Home" feature.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _streetAddressController,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              hintText: '123 Main Street, Apt 4B',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _zipCodeController,
                  decoration: const InputDecoration(labelText: 'ZIP Code'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_streetAddressController.text.isNotEmpty) ...[
            _buildSectionTitle('Address Preview'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.home, size: 32, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        [
                          _streetAddressController.text,
                          _cityController.text,
                          _stateController.text,
                          _zipCodeController.text,
                          _countryController.text,
                        ].where((s) => s.isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This information is stored securely and only used for identification purposes.',
                      style:
                          TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Driver's License"),
          TextFormField(
            controller: _driversLicenseNumberController,
            decoration: const InputDecoration(
              labelText: 'License Number',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _driversLicenseStateController,
                  decoration: const InputDecoration(labelText: 'Issuing State'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expiration'),
                  subtitle: Text(_driversLicenseExpiration != null
                      ? DateFormat('MM/dd/yyyy').format(_driversLicenseExpiration!)
                      : 'Not set'),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _driversLicenseExpiration ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) {
                      setState(() => _driversLicenseExpiration = date);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Other Identification'),
          TextFormField(
            controller: _ssnLast4Controller,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'SSN (Last 4 digits only)',
              hintText: 'XXXX',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passportNumberController,
            decoration: const InputDecoration(
              labelText: 'Passport Number',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Insurance Numbers'),
          TextFormField(
            controller: _medicareNumberController,
            decoration: const InputDecoration(
              labelText: 'Medicare Number',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicaidNumberController,
            decoration: const InputDecoration(
              labelText: 'Medicaid Number',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalAlertTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.medical_services, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This information is critical for first responders if the person is found.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Medical Information'),
          TextFormField(
            controller: _primaryDiagnosisController,
            decoration: const InputDecoration(
              labelText: 'Primary Diagnosis',
              hintText: "e.g., Alzheimer's Disease, Dementia",
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cognitiveStatusController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Cognitive Status',
              hintText: 'e.g., May not know name, non-verbal, confused',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _wanderingHistoryController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Wandering History',
              hintText: 'e.g., Has wandered 3 times in past year',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicalAlertInfoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Medical Alert Info',
              hintText: 'Critical info for first responders (allergies, conditions)',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Communication & Behavior'),
          TextFormField(
            controller: _communicationAbilityController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Communication Ability',
              hintText: 'e.g., Can state first name only, speaks Spanish',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _responseToNameController,
            decoration: const InputDecoration(
              labelText: 'Response to Name',
              hintText: 'e.g., Responds to "Bobby", not "Robert"',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _responseToStrangersController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Response to Strangers',
              hintText: 'e.g., Fearful, friendly, may follow anyone',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _behaviorWhenLostController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Behavior When Lost',
              hintText: 'e.g., May appear confused, will sit and wait',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Calming Strategies'),
          TextFormField(
            controller: _calmingTechniquesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Calming Techniques',
              hintText: 'What helps calm them (music, photos, etc.)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _triggersToAvoidController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Triggers to Avoid',
              hintText: 'What upsets them (loud noises, crowds, etc.)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    final photos = _profile?.photos ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.photo_camera, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${photos.length} photo${photos.length == 1 ? '' : 's'} • Recent photos help with identification',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add Photo'),
              ),
            ],
          ),
        ),
        if (photos.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add photos for identification purposes',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add First Photo'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _buildPhotoCard(photo);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoCard(UserPhoto photo) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.error),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRIMARY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (photo.photoType != null)
                    Text(
                      photo.photoType!.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  Text(
                    DateFormat('MMM d, yyyy').format(photo.dateTaken),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
              ),
              onSelected: (value) {
                if (value == 'primary') {
                  _setAsPrimary(photo);
                } else if (value == 'delete') {
                  _deletePhoto(photo);
                }
              },
              itemBuilder: (context) => [
                if (!photo.isPrimary)
                  const PopupMenuItem(
                    value: 'primary',
                    child: Row(
                      children: [
                        Icon(Icons.star),
                        SizedBox(width: 8),
                        Text('Set as Primary'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  // ==========================================================================
  // VEHICLES
  // ==========================================================================

  /// The working list of vehicles: the stored structured list if present,
  /// otherwise the legacy single-vehicle fields folded into a list so older
  /// profiles migrate cleanly on first edit.
  List<Vehicle> _currentVehicles() {
    final v = _profile?.vehicles ?? const <Vehicle>[];
    if (v.isNotEmpty) return List<Vehicle>.from(v);
    return List<Vehicle>.from(_profile?.allVehicles ?? const <Vehicle>[]);
  }

  Future<void> _persistVehicles(List<Vehicle> vehicles) async {
    final updated = _profile?.copyWith(
          vehicles: vehicles,
          updatedAt: DateTime.now(),
        ) ??
        UserProfile(
          id: '',
          userId: widget.userId,
          vehicles: vehicles,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    await UserProfileService.saveUserProfile(widget.userId, updated);
    if (mounted) setState(() => _profile = updated);
  }

  Widget _buildVehiclesTab() {
    final vehicles = _profile?.allVehicles ?? const <Vehicle>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} • Included on missing-person flyers',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditVehicle(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        if (vehicles.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No vehicles yet',
                      style: TextStyle(
                          fontSize: 18, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('Add a vehicle so it can appear on flyers',
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditVehicle(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Vehicle'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) => _buildVehicleCard(vehicles[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildVehicleCard(Vehicle v) {
    final subtitleLines = <String>[
      if (v.licensePlate != null && v.licensePlate!.isNotEmpty)
        'Plate: ${v.licensePlate}${v.licenseState != null && v.licenseState!.isNotEmpty ? ' (${v.licenseState})' : ''}',
      if (v.vin != null && v.vin!.isNotEmpty) 'VIN: ${v.vin}',
      if (v.notes != null && v.notes!.isNotEmpty) v.notes!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.photoUrls.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: v.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: v.photoUrls[i],
                    width: 180,
                    height: 114,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 180,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 180,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
              ),
            ),
          ListTile(
            title: Text(v.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: subtitleLines.isEmpty
                ? null
                : Text(subtitleLines.join('\n')),
            isThreeLine: subtitleLines.length > 1,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _addOrEditVehicle(existing: v);
                } else if (value == 'delete') {
                  _deleteVehicle(v);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditVehicle({Vehicle? existing}) async {
    final result = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(
        builder: (_) => _VehicleEditorScreen(
          userId: widget.userId,
          vehicle: existing,
        ),
      ),
    );
    if (result == null) return;

    final list = _currentVehicles();
    final idx = list.indexWhere((e) => e.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      list.add(result);
    }
    await _persistVehicles(list);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Delete "${v.displayName}" and its photos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final url in v.photoUrls) {
      await UserProfileService.deleteVehiclePhoto(url);
    }
    final list = _currentVehicles()..removeWhere((e) => e.id == v.id);
    await _persistVehicles(list);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle deleted'), backgroundColor: Colors.green),
      );
    }
  }

  // ==========================================================================
  // SOCIAL MEDIA
  // ==========================================================================

  Future<void> _persistSocialLinks(List<SocialMediaLink> links) async {
    final updated = _profile?.copyWith(
          socialMediaLinks: links,
          updatedAt: DateTime.now(),
        ) ??
        UserProfile(
          id: '',
          userId: widget.userId,
          socialMediaLinks: links,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    await UserProfileService.saveUserProfile(widget.userId, updated);
    if (mounted) setState(() => _profile = updated);
  }

  IconData _socialIcon(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.instagram:
        return Icons.camera_alt;
      case SocialPlatform.twitter:
        return Icons.alternate_email;
      case SocialPlatform.tiktok:
        return Icons.music_note;
      case SocialPlatform.other:
        return Icons.link;
    }
  }

  Color _socialColor(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.facebook:
        return const Color(0xFF1877F2);
      case SocialPlatform.instagram:
        return const Color(0xFFE4405F);
      case SocialPlatform.twitter:
        return Colors.black;
      case SocialPlatform.tiktok:
        return Colors.black;
      case SocialPlatform.other:
        return Colors.blue;
    }
  }

  Widget _buildSocialMediaTab() {
    final links = _profile?.socialMediaLinks ?? const <SocialMediaLink>[];
    SocialMediaLink? forPlatform(SocialPlatform p) {
      for (final l in links) {
        if (l.platform == p.key) return l;
      }
      return null;
    }

    const known = [
      SocialPlatform.facebook,
      SocialPlatform.instagram,
      SocialPlatform.twitter,
      SocialPlatform.tiktok,
    ];
    final others =
        links.where((l) => l.platform == SocialPlatform.other.key).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Link social accounts so caregivers can quickly pull recent '
                  'photos for a flyer, and the public can reference them.',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...known.map((p) => _buildSocialTile(p, forPlatform(p))),
        const SizedBox(height: 8),
        const Divider(),
        _buildSectionTitle('Other Links'),
        if (others.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('No other links added.',
                style: TextStyle(color: Colors.grey.shade500)),
          )
        else
          ...others.map((l) => _buildOtherSocialTile(l)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _editSocialLink(platform: SocialPlatform.other),
          icon: const Icon(Icons.add),
          label: const Text('Add other link'),
        ),
      ],
    );
  }

  Widget _buildSocialTile(SocialPlatform p, SocialMediaLink? link) {
    final linked = link != null && link.url.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_socialIcon(p),
            color: linked ? _socialColor(p) : Colors.grey.shade400),
        title: Text(p.label),
        subtitle: linked
            ? Text(
                link.handle != null && link.handle!.isNotEmpty
                    ? '${link.handle} · ${link.url}'
                    : link.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text('Not linked',
                style: TextStyle(color: Colors.grey.shade500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (linked)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open',
                onPressed: () => _openUrl(link.url),
              ),
            IconButton(
              icon: Icon(linked ? Icons.edit : Icons.add),
              tooltip: linked ? 'Edit' : 'Add',
              onPressed: () => _editSocialLink(platform: p, existing: link),
            ),
          ],
        ),
        onTap: linked
            ? () => _openUrl(link.url)
            : () => _editSocialLink(platform: p),
      ),
    );
  }

  Widget _buildOtherSocialTile(SocialMediaLink l) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.link, color: Colors.blue.shade400),
        title: Text(
          l.handle != null && l.handle!.isNotEmpty ? l.handle! : l.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(l.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open',
              onPressed: () => _openUrl(l.url),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () =>
                  _editSocialLink(platform: SocialPlatform.other, existing: l),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _deleteSocialLink(l),
            ),
          ],
        ),
        onTap: () => _openUrl(l.url),
      ),
    );
  }

  Future<void> _editSocialLink({
    required SocialPlatform platform,
    SocialMediaLink? existing,
  }) async {
    final urlController = TextEditingController(text: existing?.url ?? '');
    final handleController =
        TextEditingController(text: existing?.handle ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${existing == null ? 'Add' : 'Edit'} ${platform.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: handleController,
              decoration: InputDecoration(
                labelText:
                    platform == SocialPlatform.other ? 'Label' : 'Handle',
                hintText: platform == SocialPlatform.other
                    ? 'e.g. Snapchat'
                    : 'e.g. @janedoe',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Profile URL',
                hintText: 'https://…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final url = urlController.text.trim();
    final handle = handleController.text.trim();

    final list = List<SocialMediaLink>.from(
        _profile?.socialMediaLinks ?? const <SocialMediaLink>[]);

    if (platform == SocialPlatform.other) {
      if (existing != null) {
        list.removeWhere((l) => identical(l, existing));
      }
    } else {
      // At most one link per known platform.
      list.removeWhere((l) => l.platform == platform.key);
    }

    if (url.isNotEmpty) {
      list.add(SocialMediaLink(
        platform: platform.key,
        url: url,
        handle: handle.isEmpty ? null : handle,
      ));
    }

    await _persistSocialLinks(list);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(url.isEmpty ? 'Link removed' : 'Link saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSocialLink(SocialMediaLink link) async {
    final list = List<SocialMediaLink>.from(
        _profile?.socialMediaLinks ?? const <SocialMediaLink>[])
      ..removeWhere((l) => identical(l, link));
    await _persistSocialLinks(list);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link removed'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _openUrl(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  // ==========================================================================
  // MISSING PERSON FLYER (PDF)
  // ==========================================================================

  Future<void> _generateFlyer() async {
    final options = await showDialog<FlyerOptions>(
      context: context,
      builder: (_) => const _FlyerOptionsDialog(),
    );
    if (options == null) return; // cancelled

    setState(() => _isGeneratingFlyer = true);
    try {
      final report =
          await UserProfileService.generateLostPersonReport(widget.userId);
      final bytes = await MissingPersonFlyerService.generateFlyer(
        report,
        options: options,
      );

      if (!mounted) return;
      setState(() => _isGeneratingFlyer = false);

      final safeName =
          report.userName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              title: const Text('Missing Person Flyer'),
            ),
            body: PdfPreview(
              build: (_) => bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName: 'missing_person_$safeName.pdf',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingFlyer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating flyer: $e')),
        );
      }
    }
  }
}

// ============================================================================
// Vehicle editor — full-screen form for adding/editing one vehicle, with
// immediate photo upload to Firebase Storage. Returns the edited [Vehicle]
// to the caller (which persists it onto the profile).
// ============================================================================
class _VehicleEditorScreen extends StatefulWidget {
  final String userId;
  final Vehicle? vehicle;

  const _VehicleEditorScreen({required this.userId, this.vehicle});

  @override
  State<_VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<_VehicleEditorScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  late final String _id;
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _stateController = TextEditingController();
  final _vinController = TextEditingController();
  final _notesController = TextEditingController();

  List<String> _photoUrls = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _id = v?.id ?? const Uuid().v4();
    _makeController.text = v?.make ?? '';
    _modelController.text = v?.model ?? '';
    _yearController.text = v?.year?.toString() ?? '';
    _colorController.text = v?.color ?? '';
    _plateController.text = v?.licensePlate ?? '';
    _stateController.text = v?.licenseState ?? '';
    _vinController.text = v?.vin ?? '';
    _notesController.text = v?.notes ?? '';
    _photoUrls = List<String>.from(v?.photoUrls ?? const []);
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _stateController.dispose();
    _vinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _uploading = true);
      final bytes = await File(image.path).readAsBytes();
      final url =
          await UserProfileService.uploadVehiclePhoto(widget.userId, bytes);
      if (url == null) throw Exception('Upload failed');

      if (mounted) {
        setState(() {
          _photoUrls.add(url);
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding photo: $e')),
        );
      }
    }
  }

  Future<void> _removePhoto(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Remove this vehicle photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await UserProfileService.deleteVehiclePhoto(url);
    if (mounted) setState(() => _photoUrls.remove(url));
  }

  void _save() {
    String? nn(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final vehicle = Vehicle(
      id: _id,
      make: nn(_makeController),
      model: nn(_modelController),
      year: int.tryParse(_yearController.text.trim()),
      color: nn(_colorController),
      licensePlate: nn(_plateController),
      licenseState: nn(_stateController),
      vin: nn(_vinController),
      notes: nn(_notesController),
      photoUrls: _photoUrls,
    );
    Navigator.pop(context, vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _save,
            child: const Text('SAVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photos
          Row(
            children: [
              const Icon(Icons.photo_camera, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${_photoUrls.length} photo${_photoUrls.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _addPhoto,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo),
                label: const Text('Add Photo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photoUrls.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final url = _photoUrls[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 160,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 160,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(url),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          // Fields
          TextField(
            controller: _makeController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Make', hintText: 'e.g. Toyota'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Model', hintText: 'e.g. Camry'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                      labelText: 'Year', counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _colorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Color', hintText: 'e.g. Silver'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'License Plate', hintText: 'e.g. ABC1234'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _stateController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(
                      labelText: 'State', counterText: '', hintText: 'AZ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vinController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'VIN (optional)',
                hintText: 'Vehicle Identification Number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Dent on rear bumper, roof rack',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// Flyer options dialog — captures per-incident details (last seen, contact)
// that aren't stored on the profile. Returns a [FlyerOptions] on Generate,
// or null on Cancel.
// ============================================================================
class _FlyerOptionsDialog extends StatefulWidget {
  const _FlyerOptionsDialog();

  @override
  State<_FlyerOptionsDialog> createState() => _FlyerOptionsDialogState();
}

class _FlyerOptionsDialogState extends State<_FlyerOptionsDialog> {
  final _locationController = TextEditingController();
  final _wearingController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _additionalController = TextEditingController();
  DateTime? _lastSeenAt;

  @override
  void dispose() {
    _locationController.dispose();
    _wearingController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _lastSeenAt ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_lastSeenAt ?? now),
    );
    setState(() {
      _lastSeenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Flyer Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional — these appear on the flyer. Leave blank to skip.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Last seen (date & time)',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _lastSeenAt == null
                        ? 'Tap to select'
                        : DateFormat('EEE, MMM d, yyyy · h:mm a')
                            .format(_lastSeenAt!),
                    style: TextStyle(
                      color: _lastSeenAt == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Last seen location',
                  hintText: 'e.g. Reid Park, Tucson',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wearingController,
                decoration: const InputDecoration(
                  labelText: 'Last seen wearing',
                  hintText: 'e.g. Blue jacket, jeans',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactNameController,
                decoration: const InputDecoration(
                  labelText: 'Contact name',
                  hintText: 'Who to call (besides 911)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact phone',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _additionalController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Additional information',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            String? nn(TextEditingController c) =>
                c.text.trim().isEmpty ? null : c.text.trim();
            Navigator.pop(
              context,
              FlyerOptions(
                lastSeenLocation: nn(_locationController),
                lastSeenAt: _lastSeenAt,
                lastSeenWearing: nn(_wearingController),
                contactName: nn(_contactNameController),
                contactPhone: nn(_contactPhoneController),
                additionalInfo: nn(_additionalController),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Generate'),
        ),
      ],
    );
  }
}
