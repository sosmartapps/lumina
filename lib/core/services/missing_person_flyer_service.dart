import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/user_profile.dart';
import 'user_profile_service.dart';

/// Caregiver-supplied details captured at flyer-generation time that aren't
/// stored on the profile (they change every incident).
class FlyerOptions {
  final String? lastSeenLocation;
  final DateTime? lastSeenAt;
  final String? lastSeenWearing;
  final String? contactName;
  final String? contactPhone;
  final String? additionalInfo;

  const FlyerOptions({
    this.lastSeenLocation,
    this.lastSeenAt,
    this.lastSeenWearing,
    this.contactName,
    this.contactPhone,
    this.additionalInfo,
  });
}

/// Builds a printable / shareable missing-person flyer (PDF) from a patient's
/// [LostPersonReport]. Auto-includes the most recent patient photo, vehicle
/// photos + details, and social-media handles for public reference.
class MissingPersonFlyerService {
  static const _red = PdfColor.fromInt(0xFFD32F2F);
  static const _darkRed = PdfColor.fromInt(0xFFB71C1C);
  static const _black = PdfColor.fromInt(0xFF212121);
  static const _grey = PdfColor.fromInt(0xFF616161);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);
  static const _amberBg = PdfColor.fromInt(0xFFFFF3E0);
  static const _amber = PdfColor.fromInt(0xFFE65100);

  /// Fetch an image URL as a [pw.MemoryImage]. Returns null on any failure
  /// so the flyer degrades gracefully to a placeholder.
  static Future<pw.MemoryImage?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(resp.bodyBytes);
      }
    } catch (e) {
      debugPrint('Flyer: failed to fetch image $url: $e');
    }
    return null;
  }

  /// Generate the flyer PDF bytes.
  static Future<Uint8List> generateFlyer(
    LostPersonReport report, {
    FlyerOptions options = const FlyerOptions(),
  }) async {
    final profile = report.profile;
    final dateFmt = DateFormat('MMM d, yyyy');
    final dateTimeFmt = DateFormat('EEE, MMM d, yyyy · h:mm a');

    // Pre-fetch images (network) before building the document.
    final mainPhoto = await _fetchImage(profile?.mostRecentPhoto?.url);

    final vehicles = profile?.allVehicles ?? const <Vehicle>[];
    final vehiclePhotos = <String, pw.MemoryImage?>{};
    for (final v in vehicles) {
      if (v.photoUrls.isNotEmpty) {
        vehiclePhotos[v.id] = await _fetchImage(v.photoUrls.first);
      }
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    // Resolve the display name.
    final name = (profile?.fullLegalName.isNotEmpty == true)
        ? profile!.fullLegalName
        : report.userName;
    final preferred = profile?.preferredName;

    // Physical description key/value pairs.
    final physical = <List<String>>[];
    void addPhys(String k, String? v) {
      if (v != null && v.trim().isNotEmpty) physical.add([k, v.trim()]);
    }

    if (profile != null) {
      if (profile.age != null) {
        addPhys('Age', '${profile.age}');
      }
      addPhys('Sex', profile.gender);
      addPhys('Race', profile.race);
      if (profile.heightImperial != null || profile.heightCm != null) {
        addPhys('Height', profile.heightImperial ?? '${profile.heightCm} cm');
      }
      if (profile.weightLbs != null) {
        addPhys('Weight', '${profile.weightLbs!.round()} lbs');
      }
      addPhys('Build', profile.buildType);
      addPhys('Hair', profile.hairColor);
      addPhys('Eyes', profile.eyeColor);
      addPhys('Skin tone', profile.skinTone);
      addPhys('Glasses', profile.glasses);
      addPhys('Mobility aids', profile.mobilityAids);
    }

    // Contact numbers — prefer explicit option, then emergency contacts,
    // de-duplicated by digits so the same number isn't listed twice.
    final contactLines = <String>[];
    final seenPhones = <String>{};
    String digits(String s) => s.replaceAll(RegExp(r'\D'), '');
    if (options.contactPhone != null && options.contactPhone!.isNotEmpty) {
      final who = (options.contactName != null &&
              options.contactName!.isNotEmpty)
          ? '${options.contactName}: '
          : '';
      contactLines.add('$who${options.contactPhone}');
      seenPhones.add(digits(options.contactPhone!));
    }
    for (final c in report.emergencyContacts) {
      final phone = c['phoneNumber'];
      if (phone == null || phone.toString().isEmpty) continue;
      if (!seenPhones.add(digits(phone.toString()))) continue;
      final cn = c['name'] ?? 'Contact';
      final rel = c['relationship'] != null ? ' (${c['relationship']})' : '';
      contactLines.add('$cn$rel: $phone');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // ── MISSING banner ───────────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: _red,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'MISSING PERSON',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'PLEASE HELP - IF SEEN, CALL 911 IMMEDIATELY',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Name ─────────────────────────────────────────────────────
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                ),
                if (preferred != null && preferred.isNotEmpty)
                  pw.Text(
                    'Also responds to: $preferred',
                    style: const pw.TextStyle(fontSize: 13, color: _grey),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Photo + physical description side by side ────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Photo
              pw.Container(
                width: 210,
                height: 250,
                decoration: pw.BoxDecoration(
                  color: _lightGrey,
                  border: pw.Border.all(color: _grey, width: 1),
                ),
                child: mainPhoto != null
                    ? pw.Image(mainPhoto, fit: pw.BoxFit.cover)
                    : pw.Center(
                        child: pw.Text(
                          'NO PHOTO\nON FILE',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(color: _grey, fontSize: 14),
                        ),
                      ),
              ),
              pw.SizedBox(width: 16),
              // Physical description
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('PHYSICAL DESCRIPTION'),
                    pw.SizedBox(height: 6),
                    if (physical.isEmpty)
                      pw.Text('(Not on file)',
                          style: const pw.TextStyle(color: _grey, fontSize: 12))
                    else
                      pw.Wrap(
                        spacing: 16,
                        runSpacing: 2,
                        children: physical
                            .map((kv) => _kvRow(kv[0], kv[1]))
                            .toList(),
                      ),
                    if (profile?.distinguishingMarks != null &&
                        profile!.distinguishingMarks!.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      _inlineNote('Distinguishing marks',
                          profile.distinguishingMarks!),
                    ],
                    if (profile?.usualClothing != null &&
                        profile!.usualClothing!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      _inlineNote('Usually wears', profile.usualClothing!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Last seen ────────────────────────────────────────────────
          if (options.lastSeenLocation != null ||
              options.lastSeenAt != null ||
              options.lastSeenWearing != null)
            _panel(
              'LAST SEEN',
              color: _amberBg,
              borderColor: _amber,
              children: [
                if (options.lastSeenAt != null)
                  _kvRow('When', dateTimeFmt.format(options.lastSeenAt!)),
                if (options.lastSeenLocation != null &&
                    options.lastSeenLocation!.isNotEmpty)
                  _kvRow('Where', options.lastSeenLocation!),
                if (options.lastSeenWearing != null &&
                    options.lastSeenWearing!.isNotEmpty)
                  _kvRow('Wearing', options.lastSeenWearing!),
              ],
            ),

          // Home / frequent places
          if (profile?.fullAddress.isNotEmpty == true ||
              (profile?.frequentPlaces.isNotEmpty ?? false)) ...[
            pw.SizedBox(height: 10),
            _panel(
              'AREAS TO CHECK',
              color: _lightGrey,
              borderColor: _grey,
              children: [
                if (profile?.fullAddress.isNotEmpty == true)
                  _kvRow('Home', profile!.fullAddress),
                ...?profile?.frequentPlaces.map(
                  (p) => _kvRow(
                    p.name,
                    [p.address, p.notes]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' - '),
                  ),
                ),
              ],
            ),
          ],

          // ── Medical alert ────────────────────────────────────────────
          if (_hasMedicalAlert(profile, report)) ...[
            pw.SizedBox(height: 10),
            _panel(
              'MEDICAL ALERT',
              color: _amberBg,
              borderColor: _amber,
              children: [
                if (profile?.primaryDiagnosis != null &&
                    profile!.primaryDiagnosis!.isNotEmpty)
                  _kvRow('Condition', profile.primaryDiagnosis!),
                if (profile?.cognitiveStatus != null &&
                    profile!.cognitiveStatus!.isNotEmpty)
                  _kvRow('Cognitive', profile.cognitiveStatus!),
                if (profile?.communicationAbility != null &&
                    profile!.communicationAbility!.isNotEmpty)
                  _kvRow('Communication', profile.communicationAbility!),
                if (profile?.behaviorWhenLost != null &&
                    profile!.behaviorWhenLost!.isNotEmpty)
                  _kvRow('If approached', profile.behaviorWhenLost!),
                if (profile?.medicalAlertInfo != null &&
                    profile!.medicalAlertInfo!.isNotEmpty)
                  _kvRow('Note', profile.medicalAlertInfo!),
              ],
            ),
          ],

          // ── Vehicle(s) ───────────────────────────────────────────────
          if (vehicles.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionLabel('VEHICLE'),
            pw.SizedBox(height: 6),
            ...vehicles.map((v) => _vehicleBlock(v, vehiclePhotos[v.id])),
          ],

          // ── Social media ─────────────────────────────────────────────
          if ((profile?.socialMediaLinks ?? const [])
              .where((s) => s.url.isNotEmpty)
              .isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionLabel('SOCIAL MEDIA (recent photos / reference)'),
            pw.SizedBox(height: 4),
            ...profile!.socialMediaLinks
                .where((s) => s.url.isNotEmpty)
                .map((s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(
                        '${s.platformEnum.label}: ${s.handle != null && s.handle!.isNotEmpty ? '${s.handle}  ' : ''}${s.url}',
                        style: const pw.TextStyle(fontSize: 11, color: _black),
                      ),
                    )),
          ],

          // ── Additional info ──────────────────────────────────────────
          if (options.additionalInfo != null &&
              options.additionalInfo!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionLabel('ADDITIONAL INFORMATION'),
            pw.SizedBox(height: 4),
            pw.Text(options.additionalInfo!,
                style: const pw.TextStyle(fontSize: 11, color: _black)),
          ],

          // ── Contact footer ───────────────────────────────────────────
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _darkRed,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'IF YOU SEE THIS PERSON, CALL 911',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (contactLines.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Then contact:',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 10),
                  ),
                  ...contactLines.map(
                    (l) => pw.Text(
                      l,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Generated by Lumina Care · ${dateFmt.format(report.generatedAt)}',
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Layout helpers ─────────────────────────────────────────────────────

  static bool _hasMedicalAlert(UserProfile? p, LostPersonReport r) {
    if (p == null) return false;
    return [
      p.primaryDiagnosis,
      p.cognitiveStatus,
      p.communicationAbility,
      p.behaviorWhenLost,
      p.medicalAlertInfo,
    ].any((v) => v != null && v.isNotEmpty);
  }

  static pw.Widget _sectionLabel(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      color: _black,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _kvRow(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$key: ',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _black,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 11, color: _black),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _inlineNote(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _black,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 11, color: _black),
          ),
        ],
      ),
    );
  }

  static pw.Widget _panel(
    String title, {
    required PdfColor color,
    required PdfColor borderColor,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(color: borderColor, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: borderColor,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _vehicleBlock(Vehicle v, pw.MemoryImage? photo) {
    final details = <pw.Widget>[
      _kvRow('Vehicle', v.displayName),
    ];
    if (v.licensePlate != null && v.licensePlate!.isNotEmpty) {
      final plate = v.licenseState != null && v.licenseState!.isNotEmpty
          ? '${v.licensePlate} (${v.licenseState})'
          : v.licensePlate!;
      details.add(_kvRow('License plate', plate));
    }
    if (v.vin != null && v.vin!.isNotEmpty) details.add(_kvRow('VIN', v.vin!));
    if (v.notes != null && v.notes!.isNotEmpty) {
      details.add(_kvRow('Notes', v.notes!));
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (photo != null) ...[
            pw.Container(
              width: 130,
              height: 90,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _grey, width: 1),
              ),
              child: pw.Image(photo, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: details,
            ),
          ),
        ],
      ),
    );
  }
}
