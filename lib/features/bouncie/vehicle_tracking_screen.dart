import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/bouncie_connection.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'bouncie_service.dart';

/// Connect a family's own Bouncie account to a patient, pick the vehicle
/// to track, or disconnect. Replaces the old app-wide .env credentials.
class VehicleTrackingScreen extends ConsumerStatefulWidget {
  const VehicleTrackingScreen({super.key});

  @override
  ConsumerState<VehicleTrackingScreen> createState() =>
      _VehicleTrackingScreenState();
}

class _VehicleTrackingScreenState extends ConsumerState<VehicleTrackingScreen>
    with WidgetsBindingObserver {
  final _codeController = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>>? _vehicles; // fetched with the pasted code
  String? _validatedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    super.dispose();
  }

  /// When the user returns from the Bouncie sign-in browser with the code
  /// (or the whole redirect URL) on the clipboard, fill the field for them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryClipboardCode();
    }
  }

  Future<void> _tryClipboardCode() async {
    if (_vehicles != null) return; // already past the code step
    if (_codeController.text.isNotEmpty) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;

    String? code;
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.queryParameters['code']?.isNotEmpty ?? false)) {
      // Whole redirect URL copied from the address bar
      code = uri.queryParameters['code'];
    } else if (RegExp(r'^[A-Za-z0-9\-_.]{16,128}$').hasMatch(text)) {
      // Bare code copied from the page
      code = text;
    }

    if (code != null && mounted) {
      setState(() => _codeController.text = code!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Authorization code filled from clipboard — tap Continue'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(caregiverNotifierProvider).selectedUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Vehicle Tracking'),
      ),
      body: patient == null
          ? const Center(child: Text('No user selected'))
          : ref.watch(bouncieConnectionProvider(patient.id)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (connection) => connection != null
                    ? _buildConnected(patient.id, connection)
                    : _buildConnectFlow(patient.id),
              ),
    );
  }

  // ── Connected state ────────────────────────────────────────────────────

  Widget _buildConnected(String patientId, BouncieConnection connection) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car,
                      color: AppTheme.primaryGreen, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.nickName ?? 'Vehicle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (connection.model != null)
                        Text(
                          connection.model!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Connected via Bouncie',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _disconnect(patientId),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
              side: const BorderSide(color: AppTheme.primaryRed),
            ),
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect Vehicle'),
          ),
        ),
      ],
    );
  }

  Future<void> _disconnect(String patientId) async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('bouncie_connections')
          .doc(patientId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not disconnect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Connect flow ───────────────────────────────────────────────────────

  Widget _buildConnectFlow(String patientId) {
    final config = ref.read(bouncieAppConfigProvider);
    final configured =
        config.clientId.isNotEmpty && config.clientSecret.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Track the family vehicle with a Bouncie GPS adapter. '
                  'Sign in with YOUR Bouncie account — only your family '
                  'sees this vehicle.',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://www.bouncie.com'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text("Don't have one? Order a Bouncie adapter"),
          ),
        ),
        const SizedBox(height: 16),

        if (!configured)
          const Text('Vehicle tracking is not configured for this app build.')
        else if (_vehicles == null) ...[
          // Step 1: authorize
          const Text('Step 1 — Sign in to Bouncie',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(BouncieService.authorizeUrl(
                  clientId: config.clientId,
                  redirectUri: config.redirectUri,
                )),
                mode: LaunchMode.externalApplication,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open Bouncie Sign-In'),
            ),
          ),
          const SizedBox(height: 24),

          // Step 2: paste code
          const Text('Step 2 — Paste your authorization code',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'After signing in, copy the code from the page (or the "code=" '
            'part of the address bar) and paste it here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(
                  '[\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u206F\\uFEFF\\s]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Authorization code',
              prefixIcon: Icon(Icons.vpn_key),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _validateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_busy ? 'Checking…' : 'Continue'),
            ),
          ),
        ] else ...[
          // Step 3: pick the vehicle
          const Text('Step 3 — Choose the vehicle to track',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (_vehicles!.isEmpty)
            const Text('No vehicles found on this Bouncie account.')
          else
            ..._vehicles!.map((v) {
              final model = v['model'] as Map<String, dynamic>?;
              final modelStr = model == null
                  ? null
                  : '${model['year'] ?? ''} ${model['make'] ?? ''} ${model['name'] ?? ''}'
                      .trim();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car,
                      color: AppTheme.primaryBlue),
                  title: Text(
                    (v['nickName'] as String?) ?? modelStr ?? 'Vehicle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: modelStr != null
                      ? Text(modelStr,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: () => _saveConnection(patientId, v),
                ),
              );
            }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _vehicles = null;
                      _validatedCode = null;
                    }),
            child: const Text('Start over'),
          ),
        ],
      ],
    );
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);

    try {
      final config = ref.read(bouncieAppConfigProvider);
      final service = BouncieService(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        authCode: code,
        redirectUri: config.redirectUri,
      );
      final vehicles =
          await service.getVehicles().timeout(const Duration(seconds: 20));
      setState(() {
        _vehicles = vehicles;
        _validatedCode = code;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not verify the code — check it was copied completely '
                'and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveConnection(
      String patientId, Map<String, dynamic> vehicle) async {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    setState(() => _busy = true);
    try {
      final model = vehicle['model'] as Map<String, dynamic>?;
      final modelStr = model == null
          ? null
          : '${model['year'] ?? ''} ${model['make'] ?? ''} ${model['name'] ?? ''}'
              .trim();
      final connection = BouncieConnection(
        userId: patientId,
        authCode: _validatedCode!,
        imei: vehicle['imei'] as String,
        nickName: vehicle['nickName'] as String?,
        model: modelStr,
        connectedBy: caregiver?.id ?? '',
      );
      await FirebaseFirestore.instance
          .collection('bouncie_connections')
          .doc(patientId)
          .set(connection.toFirestore());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle connected')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save connection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
