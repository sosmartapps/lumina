import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../../core/legal/legal_terms.dart';
import '../../core/services/legal_service.dart';
import '../../core/theme/app_theme.dart';

/// Blocking Terms of Use / liability waiver screen.
///
/// GATE MODE (default): shown by SplashScreen before ANY destination when
/// [LegalService.needsAcceptance] is true — including the very first launch,
/// ahead of onboarding/setup. The user must scroll through the full terms
/// (the checkboxes and Agree button live BELOW the text, so reaching them
/// requires scrolling past everything) and check all four acknowledgments.
/// "I Do Not Agree" offers only "review again" or "close the app" — there
/// is no path into the app without acceptance. Android back is blocked.
///
/// VIEW MODE ([viewOnly] true): read-only display for Settings, with the
/// device's acceptance date in the header. No checkboxes, back allowed.
///
/// Docs: docs/legal/LEGAL-IMPLEMENTATION.md
class LegalGateScreen extends StatefulWidget {
  /// Destination to continue to after acceptance (gate mode).
  final Widget? next;
  final bool viewOnly;

  /// Account context for the acceptance record — null on true first run
  /// (accounts don't exist yet); back-filled by ensureRemoteSync later.
  final String? userId;
  final String? caregiverId;

  const LegalGateScreen({
    super.key,
    this.next,
    this.viewOnly = false,
    this.userId,
    this.caregiverId,
  });

  @override
  State<LegalGateScreen> createState() => _LegalGateScreenState();
}

class _LegalGateScreenState extends State<LegalGateScreen> {
  final List<bool> _checked =
      List<bool>.filled(kRequiredAcknowledgments.length, false);
  bool _saving = false;
  String? _acceptedDate;

  bool get _allChecked => _checked.every((c) => c);

  @override
  void initState() {
    super.initState();
    if (widget.viewOnly) {
      LegalService.localAcceptanceDateIso().then((iso) {
        if (mounted && iso != null && iso.isNotEmpty) {
          setState(() => _acceptedDate = iso.split('T').first);
        }
      });
    }
  }

  Future<void> _accept() async {
    if (!_allChecked || _saving) return;
    setState(() => _saving = true);
    try {
      await LegalService.recordAcceptance(
        userId: widget.userId,
        caregiverId: widget.caregiverId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.next ?? const SizedBox()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your acceptance. Please try again.'),
        ),
      );
    }
  }

  void _decline() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agreement required'),
        content: const Text(
          'Lumina cannot be used without accepting the Terms of Use. '
          'You can review the terms again, or close the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Review Again'),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Close App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!widget.viewOnly) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryRed, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.emergency, color: AppTheme.primaryRed, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lumina is NOT an emergency service. '
                    'In an emergency, always call 911.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Terms of Use & Liability Waiver',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $kTermsVersion — Effective $kTermsEffectiveDate'
          '${_acceptedDate != null ? '\nAccepted on this device: $_acceptedDate' : ''}',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          kTermsIntro,
          style: const TextStyle(fontSize: 15, height: 1.45),
        ),
        for (final section in kTermsSections) ...[
          const SizedBox(height: 20),
          Text(
            section.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
        ],
        if (!widget.viewOnly) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'To continue, confirm each statement:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < kRequiredAcknowledgments.length; i++)
            CheckboxListTile(
              value: _checked[i],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _checked[i] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                kRequiredAcknowledgments[i],
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _allChecked && !_saving ? _accept : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'I Agree — Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : _decline,
              child: const Text(
                'I Do Not Agree',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 24),
      ],
    );

    if (widget.viewOnly) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terms of Use')),
        body: SafeArea(child: body),
      );
    }

    // Gate mode: block the Android back button — there is no "back" from
    // the legal gate; the only exits are Agree or Close App.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(child: body),
      ),
    );
  }
}
