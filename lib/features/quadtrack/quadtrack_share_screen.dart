import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

import 'package:lumina/core/theme/app_theme.dart';
import 'package:lumina/core/providers/quadtrack_provider.dart';
import 'package:lumina/core/models/quadtrack_device.dart';
import 'package:lumina/core/models/user_profile.dart';
import 'package:lumina/core/models/health_profile.dart';
import 'package:lumina/core/models/app_user.dart';

/// Screen for sharing comprehensive patient information with law enforcement
class QuadTrackShareScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String patientId;
  final String caregiverId;

  const QuadTrackShareScreen({
    super.key,
    required this.deviceId,
    required this.patientId,
    required this.caregiverId,
  });

  @override
  ConsumerState<QuadTrackShareScreen> createState() =>
      _QuadTrackShareScreenState();
}

class _QuadTrackShareScreenState extends ConsumerState<QuadTrackShareScreen> {
  final _phoneController = TextEditingController();
  String? _addressCache;
  UserProfile? _userProfile;
  HealthProfile? _healthProfile;
  AppUser? _appUser;
  List<HealthCondition> _activeConditions = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    try {
      // Load UserProfile
      final userProfileDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.patientId)
          .get();
      if (userProfileDoc.exists) {
        setState(() {
          _userProfile = UserProfile.fromFirestore(userProfileDoc);
        });
      }

      // Load AppUser
      final appUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .get();
      if (appUserDoc.exists) {
        setState(() {
          _appUser = AppUser.fromFirestore(appUserDoc);
        });
      }

      // Load HealthProfile
      final healthProfileQuery = await FirebaseFirestore.instance
          .collection('health_profiles')
          .where('userId', isEqualTo: widget.patientId)
          .limit(1)
          .get();
      if (healthProfileQuery.docs.isNotEmpty) {
        setState(() {
          _healthProfile = HealthProfile.fromFirestore(healthProfileQuery.docs.first);
        });
      }

      // Load active health conditions
      final conditionsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('health_conditions')
          .where('isActive', isEqualTo: true)
          .get();
      if (conditionsQuery.docs.isNotEmpty) {
        setState(() {
          _activeConditions = conditionsQuery.docs
              .map((doc) => HealthCondition.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading patient data: $e');
    }
  }

  Future<String> _getAddress(double lat, double lng) async {
    if (_addressCache != null) return _addressCache!;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _addressCache =
            '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}';
        return _addressCache!;
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }

    return 'Unknown location';
  }

  String _buildShareMessage(
    QuadTrackDevice device,
    String address,
    List<QuadTrackPing> recentPings,
  ) {
    final timestamp = DateFormat('hh:mm a').format(device.lastSeenAt!);
    final date = DateFormat('MMM dd, yyyy').format(device.lastSeenAt!);

    // Build comprehensive missing person alert
    final sb = StringBuffer();
    sb.writeln('🚨 MISSING PERSON ALERT — QuadTrack\n');

    // Identity
    if (_userProfile != null) {
      sb.writeln('IDENTITY');
      sb.writeln('Name: ${_userProfile!.fullLegalName}');
      if (_userProfile!.preferredName != null && _userProfile!.preferredName!.isNotEmpty) {
        sb.writeln('Also responds to: ${_userProfile!.preferredName}');
      }
      if (_userProfile!.age != null) {
        sb.write('Age: ${_userProfile!.age}');
        if (_userProfile!.dateOfBirth != null) {
          sb.write(' | DOB: ${DateFormat('MMM dd, yyyy').format(_userProfile!.dateOfBirth!)}');
        }
        sb.writeln();
      }
      if (_userProfile!.gender != null) {
        sb.writeln('Gender: ${_userProfile!.gender}');
      }
      sb.writeln();
    }

    // Physical Description
    if (_userProfile != null) {
      sb.writeln('PHYSICAL DESCRIPTION');
      if (_userProfile!.heightImperial != null) {
        sb.write('Height: ${_userProfile!.heightImperial}');
        if (_userProfile!.weightLbs != null) {
          sb.write(' | Weight: ${_userProfile!.weightLbs!.toStringAsFixed(0)} lbs');
        }
        sb.writeln();
      }
      if (_userProfile!.hairColor != null || _userProfile!.eyeColor != null) {
        sb.write('Hair: ${_userProfile!.hairColor ?? 'Unknown'}');
        sb.writeln(' | Eyes: ${_userProfile!.eyeColor ?? 'Unknown'}');
      }
      if (_userProfile!.race != null) {
        sb.write('Race: ${_userProfile!.race}');
        if (_userProfile!.buildType != null) {
          sb.write(' | Build: ${_userProfile!.buildType}');
        }
        sb.writeln();
      }
      if (_userProfile!.distinguishingMarks != null && _userProfile!.distinguishingMarks!.isNotEmpty) {
        sb.writeln('Distinguishing Marks: ${_userProfile!.distinguishingMarks}');
      }
      if (_userProfile!.usualClothing != null && _userProfile!.usualClothing!.isNotEmpty) {
        sb.writeln('Usually Wears: ${_userProfile!.usualClothing}');
      }
      if (_userProfile!.glasses != null || _userProfile!.mobilityAids != null) {
        sb.write('Glasses: ${_userProfile!.glasses ?? 'None'}');
        sb.writeln(' | Mobility: ${_userProfile!.mobilityAids ?? 'None'}');
      }
      sb.writeln();
    }

    // Medical Information
    if (_userProfile != null || _healthProfile != null || _activeConditions.isNotEmpty) {
      sb.writeln('MEDICAL INFORMATION');
      if (_userProfile!.primaryDiagnosis != null && _userProfile!.primaryDiagnosis!.isNotEmpty) {
        sb.writeln('Primary Diagnosis: ${_userProfile!.primaryDiagnosis}');
      }
      if (_userProfile!.cognitiveStatus != null && _userProfile!.cognitiveStatus!.isNotEmpty) {
        sb.writeln('Cognitive Status: ${_userProfile!.cognitiveStatus}');
      }
      if (_userProfile!.medicalAlertInfo != null && _userProfile!.medicalAlertInfo!.isNotEmpty) {
        sb.writeln('Medical Alert: ${_userProfile!.medicalAlertInfo}');
      }
      if (_activeConditions.isNotEmpty) {
        final conditionNames = _activeConditions.map((c) => c.name).join(', ');
        sb.writeln('Conditions: $conditionNames');
      }
      if (_healthProfile?.bloodType != null) {
        sb.writeln('Blood Type: ${_healthProfile!.bloodType}');
      }
      sb.writeln();
    }

    // Behavior When Lost
    if (_userProfile != null) {
      if (_userProfile!.communicationAbility != null ||
          _userProfile!.behaviorWhenLost != null ||
          _userProfile!.responseToName != null ||
          _userProfile!.responseToStrangers != null ||
          _userProfile!.calmingTechniques != null ||
          _userProfile!.triggersToAvoid != null) {
        sb.writeln('BEHAVIOR WHEN LOST');
        if (_userProfile!.communicationAbility != null && _userProfile!.communicationAbility!.isNotEmpty) {
          sb.writeln('Communication: ${_userProfile!.communicationAbility}');
        }
        if (_userProfile!.behaviorWhenLost != null && _userProfile!.behaviorWhenLost!.isNotEmpty) {
          sb.writeln('Behavior: ${_userProfile!.behaviorWhenLost}');
        }
        if (_userProfile!.responseToName != null && _userProfile!.responseToName!.isNotEmpty) {
          sb.writeln('Responds to Name: ${_userProfile!.responseToName}');
        }
        if (_userProfile!.responseToStrangers != null && _userProfile!.responseToStrangers!.isNotEmpty) {
          sb.writeln('Response to Strangers: ${_userProfile!.responseToStrangers}');
        }
        if (_userProfile!.calmingTechniques != null && _userProfile!.calmingTechniques!.isNotEmpty) {
          sb.writeln('Calming Techniques: ${_userProfile!.calmingTechniques}');
        }
        if (_userProfile!.triggersToAvoid != null && _userProfile!.triggersToAvoid!.isNotEmpty) {
          sb.writeln('Avoid: ${_userProfile!.triggersToAvoid}');
        }
        sb.writeln();
      }
    }

    // Vehicle
    if (_userProfile != null) {
      if (_userProfile!.vehicleMake != null ||
          _userProfile!.vehicleModel != null ||
          _userProfile!.vehicleYear != null ||
          _userProfile!.vehicleColor != null ||
          _userProfile!.vehicleLicensePlate != null) {
        sb.writeln('VEHICLE (if known)');
        if (_userProfile!.vehicleYear != null ||
            _userProfile!.vehicleMake != null ||
            _userProfile!.vehicleModel != null) {
          sb.write('${_userProfile!.vehicleYear ?? ''} '
              '${_userProfile!.vehicleMake ?? ''} '
              '${_userProfile!.vehicleModel ?? ''}'.trim());
          if (_userProfile!.vehicleColor != null) {
            sb.write(' — ${_userProfile!.vehicleColor}');
          }
          sb.writeln();
        }
        if (_userProfile!.vehicleLicensePlate != null) {
          sb.write('License Plate: ${_userProfile!.vehicleLicensePlate}');
          if (_userProfile!.vehicleLicenseState != null) {
            sb.write(' (${_userProfile!.vehicleLicenseState})');
          }
          sb.writeln();
        }
        if (_userProfile!.vehicleVin != null && _userProfile!.vehicleVin!.isNotEmpty) {
          sb.writeln('VIN: ${_userProfile!.vehicleVin}');
        }
        if (_userProfile!.vehicleNotes != null && _userProfile!.vehicleNotes!.isNotEmpty) {
          sb.writeln('Notes: ${_userProfile!.vehicleNotes}');
        }
        sb.writeln();
      }
    }

    // Last Known Location
    sb.writeln('LAST KNOWN LOCATION');
    sb.writeln('Address: $address');
    sb.writeln('Coordinates: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
    sb.writeln('Google Maps: https://maps.google.com/?q=$lat,$lng');
    sb.writeln('Last Ping: $timestamp on $date');
    sb.writeln('Tracker Battery: ${device.trackerBatteryLevel}%');
    sb.writeln('Phone: ${device.isPhoneDead ? 'Dead' : 'Alive'}');
    sb.writeln();

    // Frequent Locations
    if (_userProfile != null && _userProfile!.frequentPlaces.isNotEmpty) {
      sb.writeln('FREQUENT LOCATIONS');
      for (final place in _userProfile!.frequentPlaces) {
        sb.writeln('- ${place.name}: ${place.address ?? 'Address not provided'}');
      }
      sb.writeln();
    }

    // Emergency Contacts
    if (_appUser != null && _appUser!.emergencyContacts.isNotEmpty) {
      sb.writeln('EMERGENCY CONTACTS');
      for (final contact in _appUser!.emergencyContacts) {
        final rel = contact.relationship != null ? ' (${contact.relationship})' : '';
        sb.writeln('- ${contact.name}$rel: ${contact.phoneNumber}');
      }
      sb.writeln();
    }

    // Photo URL
    if (_userProfile != null && _userProfile!.mostRecentPhoto != null) {
      sb.writeln('PHOTO');
      sb.writeln(_userProfile!.mostRecentPhoto!.url);
      sb.writeln();
    }

    // Home Address
    if (_userProfile != null && _userProfile!.fullAddress.isNotEmpty) {
      sb.writeln('HOME ADDRESS');
      sb.writeln(_userProfile!.fullAddress);
      sb.writeln();
    }

    // Wandering History
    if (_userProfile != null && _userProfile!.wanderingHistory != null && _userProfile!.wanderingHistory!.isNotEmpty) {
      sb.writeln('Wandering History: ${_userProfile!.wanderingHistory}');
      sb.writeln();
    }

    sb.writeln('Sent via Lumina QuadTrack — So Smart Apps LLC');
    sb.write('Contact: support@sosmartapps.com');

    return sb.toString();
  }

  Future<void> _shareViaSMS(
    String address,
    List<QuadTrackPing> pings,
    QuadTrackDevice device,
  ) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (device.lastLocation == null) return;

    final message = _buildShareMessage(device, address, pings);

    // Check message length and warn if too long for SMS
    if (message.length > 160) {
      if (!mounted) return;
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Message Too Long'),
          content: Text(
            'The message is ${message.length} characters. '
            'It will be split into ${(message.length / 160).ceil()} SMS messages. '
            'Consider using the Share button for email or messaging apps instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Anyway'),
            ),
          ],
        ),
      );
      if (shouldSend != true) return;
    }

    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);

        // Log share to Firestore
        await FirebaseFirestore.instance
            .collection('quadtrack_shares')
            .add({
          'deviceId': widget.deviceId,
          'patientId': widget.patientId,
          'sharedBy': widget.caregiverId,
          'sharedWith': phone,
          'method': 'sms',
          'messageLength': message.length,
          'sharedAt': FieldValue.serverTimestamp(),
          'locationAtShare': device.lastLocation,
          'battery': device.trackerBatteryLevel,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS message sent'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SMS: $e')),
      );
    }
  }

  Future<void> _copyToClipboard(
    String address,
    List<QuadTrackPing> pings,
    QuadTrackDevice device,
  ) async {
    if (device.lastLocation == null) return;

    final message = _buildShareMessage(device, address, pings);

    await Clipboard.setData(ClipboardData(text: message));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Information copied to clipboard'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  Future<void> _shareViaShareSheet(
    String address,
    List<QuadTrackPing> pings,
    QuadTrackDevice device,
  ) async {
    if (device.lastLocation == null) return;

    final message = _buildShareMessage(device, address, pings);
    final patientName = _userProfile?.fullLegalName ?? 'Missing Person';

    final result = await Share.share(
      message,
      subject: 'Missing Person Alert - $patientName',
    );

    if (result.status == ShareResultStatus.success) {
      // Log share to Firestore
      await FirebaseFirestore.instance
          .collection('quadtrack_shares')
          .add({
        'deviceId': widget.deviceId,
        'patientId': widget.patientId,
        'sharedBy': widget.caregiverId,
        'sharedWith': 'share_sheet',
        'method': 'share',
        'messageLength': message.length,
        'sharedAt': FieldValue.serverTimestamp(),
        'locationAtShare': device.lastLocation,
        'battery': device.trackerBatteryLevel,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Information shared'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceDetailProvider(widget.deviceId));
    final pingsAsync = ref.watch(devicePingsProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Share Missing Person Alert'),
        centerTitle: true,
      ),
      body: deviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.primaryRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text('Error loading device information'),
            ],
          ),
        ),
        data: (device) {
          if (device == null || device.lastLocation == null) {
            return const Center(child: Text('Device information not available'));
          }

          return pingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading pings')),
            data: (pings) {
              return FutureBuilder<String>(
                future: _getAddress(
                  device.lastLocation!.latitude,
                  device.lastLocation!.longitude,
                ),
                builder: (context, addressSnapshot) {
                  final address = addressSnapshot.data ?? 'Loading address...';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Information Preview Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Missing Person Information',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                // Photo
                                if (_userProfile?.mostRecentPhoto != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundImage: NetworkImage(
                                        _userProfile!.mostRecentPhoto!.url,
                                      ),
                                    ),
                                  ),
                                // Identity
                                _buildPreviewRow(
                                  'Name',
                                  _userProfile?.fullLegalName ?? 'Unknown',
                                ),
                                if (_userProfile?.age != null)
                                  _buildPreviewRow(
                                    'Age',
                                    '${_userProfile!.age} years old',
                                  ),
                                if (_userProfile?.gender != null)
                                  _buildPreviewRow(
                                    'Gender',
                                    _userProfile!.gender!,
                                  ),
                                // Physical Description
                                if (_userProfile?.heightImperial != null)
                                  _buildPreviewRow(
                                    'Height/Weight',
                                    '${_userProfile!.heightImperial} / ${_userProfile!.weightLbs?.toStringAsFixed(0) ?? '?'} lbs',
                                  ),
                                if (_userProfile?.hairColor != null || _userProfile?.eyeColor != null)
                                  _buildPreviewRow(
                                    'Hair/Eyes',
                                    '${_userProfile?.hairColor ?? '?'} / ${_userProfile?.eyeColor ?? '?'}',
                                  ),
                                // Medical
                                if (_userProfile?.primaryDiagnosis != null)
                                  _buildPreviewRow(
                                    'Primary Diagnosis',
                                    _userProfile!.primaryDiagnosis!,
                                  ),
                                if (_healthProfile?.bloodType != null)
                                  _buildPreviewRow(
                                    'Blood Type',
                                    _healthProfile!.bloodType!,
                                  ),
                                // Vehicle
                                if (_userProfile?.vehicleMake != null ||
                                    _userProfile?.vehicleModel != null)
                                  _buildPreviewRow(
                                    'Vehicle',
                                    '${_userProfile?.vehicleYear ?? ''} ${_userProfile?.vehicleMake ?? ''} ${_userProfile?.vehicleModel ?? ''}'
                                        .trim(),
                                  ),
                                if (_userProfile?.vehicleLicensePlate != null)
                                  _buildPreviewRow(
                                    'License Plate',
                                    _userProfile!.vehicleLicensePlate!,
                                  ),
                                // Location
                                _buildPreviewRow('Last Location', address),
                                _buildPreviewRow(
                                  'Coordinates',
                                  '${device.lastLocation!.latitude.toStringAsFixed(4)}, ${device.lastLocation!.longitude.toStringAsFixed(4)}',
                                ),
                                _buildPreviewRow(
                                  'Tracker Battery',
                                  '${device.trackerBatteryLevel}%',
                                ),
                                _buildPreviewRow(
                                  'Phone Status',
                                  device.isPhoneDead ? 'Dead' : 'Alive',
                                  isAlert: device.isPhoneDead,
                                ),
                                if (device.lastSeenAt != null)
                                  _buildPreviewRow(
                                    'Last Ping',
                                    DateFormat('hh:mm a - MMM dd, yyyy')
                                        .format(device.lastSeenAt!),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Phone number input
                        Text(
                          'Send via Text Message',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Officer's Phone Number",
                            hintText: '+1 (555) 123-4567',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _shareViaSMS(address, pings, device),
                            icon: const Icon(Icons.sms),
                            label: const Text('Send via Text'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Other sharing options
                        Text(
                          'Other Sharing Options',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'For long messages, use email or messaging apps instead of SMS',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryLight,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _copyToClipboard(address, pings, device),
                                icon: const Icon(Icons.content_copy),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _shareViaShareSheet(address, pings, device),
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Maps link
                        Card(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Open in Google Maps',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color:
                                                  AppTheme.textSecondaryLight,
                                            ),
                                      ),
                                      Text(
                                        '${device.lastLocation!.latitude.toStringAsFixed(4)}, ${device.lastLocation!.longitude.toStringAsFixed(4)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.map),
                                  onPressed: () async {
                                    final link =
                                        'https://maps.google.com/?q=${device.lastLocation!.latitude},${device.lastLocation!.longitude}';
                                    if (await canLaunchUrl(Uri.parse(link))) {
                                      await launchUrl(Uri.parse(link));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPreviewRow(
    String label,
    String value, {
    bool isAlert = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAlert ? AppTheme.primaryRed : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
