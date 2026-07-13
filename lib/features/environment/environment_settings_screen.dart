import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/environment_connection.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'environment_service.dart';

/// Link a family's SensorPush and/or Google Nest account to a patient's
/// home, set alert thresholds, or disconnect. Mirrors the Bouncie
/// per-family connect flow (vehicle_tracking_screen.dart).
class EnvironmentSettingsScreen extends ConsumerStatefulWidget {
  const EnvironmentSettingsScreen({super.key});

  @override
  ConsumerState<EnvironmentSettingsScreen> createState() =>
      _EnvironmentSettingsScreenState();
}

class _EnvironmentSettingsScreenState
    extends ConsumerState<EnvironmentSettingsScreen>
    with WidgetsBindingObserver {
  // SensorPush sign-in
  final _spEmailController = TextEditingController();
  final _spPasswordController = TextEditingController();
  List<Map<String, dynamic>>? _spSensors; // fetched after sign-in
  String? _spAuthorization;

  // Nest paste-code flow
  final _nestCodeController = TextEditingController();
  List<Map<String, dynamic>>? _nestDevices; // fetched with the pasted code
  ({String accessToken, String refreshToken})? _nestTokens;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spEmailController.dispose();
    _spPasswordController.dispose();
    _nestCodeController.dispose();
    super.dispose();
  }

  /// When the user returns from the Google sign-in browser with the code
  /// (or the whole redirect URL) on the clipboard, fill the field for them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryClipboardCode();
    }
  }

  Future<void> _tryClipboardCode() async {
    if (_nestDevices != null) return; // already past the code step
    if (_nestCodeController.text.isNotEmpty) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;

    String? code;
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.queryParameters['code']?.isNotEmpty ?? false)) {
      code = uri.queryParameters['code'];
    } else if (text.startsWith('4/')) {
      // Bare Google authorization code
      code = text;
    }

    if (code != null && mounted) {
      setState(() => _nestCodeController.text = code!);
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
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Home Environment'),
      ),
      body: patient == null
          ? const Center(child: Text('No user selected'))
          : ref.watch(environmentConnectionProvider(patient.id)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (connection) => _buildBody(patient.id, connection),
              ),
    );
  }

  Widget _buildBody(String patientId, EnvironmentConnection? connection) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.thermostat, color: AppTheme.primaryTeal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'See the temperature and humidity inside the home, and '
                  'get an alert when it gets too hot, cold, damp, or dry. '
                  'Sign in with YOUR sensor account — only your family '
                  'sees these readings.',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionHeader(Icons.sensors, 'SensorPush sensor'),
        const SizedBox(height: 8),
        if (connection?.sensorPush != null)
          _buildSensorPushConnected(patientId, connection!.sensorPush!)
        else
          _buildSensorPushConnect(patientId),
        const SizedBox(height: 24),

        _sectionHeader(Icons.home, 'Nest thermostat'),
        const SizedBox(height: 8),
        _buildNestSection(patientId, connection?.nest),
        const SizedBox(height: 24),

        if (connection != null && connection.hasAnyProvider) ...[
          _sectionHeader(Icons.notifications_active, 'Alert thresholds'),
          const SizedBox(height: 8),
          _AlertThresholds(
            patientId: patientId,
            config: connection.alerts,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // ── SensorPush ─────────────────────────────────────────────────────────

  Widget _buildSensorPushConnected(String patientId, SensorPushLink link) {
    return Card(
      child: ListTile(
        leading: Icon(
          link.needsReauth ? Icons.warning_amber_rounded : Icons.check_circle,
          color: link.needsReauth
              ? AppTheme.primaryOrange
              : AppTheme.primaryGreen,
        ),
        title: Text(
          link.sensorName ?? 'SensorPush sensor',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          link.needsReauth
              ? 'Needs to be re-linked — sign in again below'
              : 'Connected via SensorPush cloud',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: _busy ? null : () => _unlink(patientId, 'sensorpush'),
          child: const Text('Disconnect',
              style: TextStyle(color: AppTheme.primaryRed)),
        ),
      ),
    );
  }

  Widget _buildSensorPushConnect(String patientId) {
    if (_spSensors != null) {
      // Step 2: pick the sensor
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose the sensor in the home:'),
          const SizedBox(height: 8),
          if (_spSensors!.isEmpty)
            const Text('No sensors found on this SensorPush account.')
          else
            ..._spSensors!.map((s) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.sensors,
                        color: AppTheme.primaryTeal),
                    title: Text(
                      s['name'] as String? ?? 'Sensor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_busy,
                    onTap: () => _saveSensorPush(patientId, s),
                  ),
                )),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _spSensors = null;
                      _spAuthorization = null;
                    }),
            child: const Text('Start over'),
          ),
        ],
      );
    }

    // Step 1: sign in
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requires a SensorPush sensor plus their G1 WiFi Gateway in the '
          'home. Your password is used once to connect and is never stored.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _spEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'SensorPush account email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _spPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'SensorPush password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _signInSensorPush,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.link),
            label: Text(_busy ? 'Connecting…' : 'Connect SensorPush'),
          ),
        ),
      ],
    );
  }

  Future<void> _signInSensorPush() async {
    final email = _spEmailController.text.trim();
    final password = _spPasswordController.text;
    if (email.isEmpty || password.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final authorization = await SensorPushApi.authorize(email, password)
          .timeout(const Duration(seconds: 20));
      final token = await SensorPushApi.accessToken(authorization)
          .timeout(const Duration(seconds: 20));
      final sensors = await SensorPushApi.listSensors(token)
          .timeout(const Duration(seconds: 20));
      _spPasswordController.clear();
      setState(() {
        _spAuthorization = authorization;
        _spSensors = sensors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign in to SensorPush — check the '
                'email and password and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSensorPush(
      String patientId, Map<String, dynamic> sensor) async {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    setState(() => _busy = true);
    try {
      await ref.read(environmentServiceProvider).saveSensorPushLink(
            patientId,
            SensorPushLink(
              authorization: _spAuthorization!,
              sensorId: sensor['id'] as String,
              sensorName: sensor['name'] as String?,
              connectedBy: caregiver?.id ?? '',
            ),
          );
      if (!mounted) return;
      setState(() {
        _spSensors = null;
        _spAuthorization = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SensorPush connected')),
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

  // ── Nest ───────────────────────────────────────────────────────────────

  Widget _buildNestSection(String patientId, NestLink? link) {
    final config = ref.read(nestAppConfigProvider);
    final configured = config.clientId.isNotEmpty &&
        config.clientSecret.isNotEmpty &&
        config.projectId.isNotEmpty;

    if (link != null) {
      return Card(
        child: ListTile(
          leading: Icon(
            link.needsReauth
                ? Icons.warning_amber_rounded
                : Icons.check_circle,
            color: link.needsReauth
                ? AppTheme.primaryOrange
                : AppTheme.primaryGreen,
          ),
          title: Text(
            link.displayName ?? 'Nest thermostat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            link.needsReauth
                ? 'Needs to be re-linked — sign in again below'
                : 'Connected via Google Nest',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: _busy ? null : () => _unlink(patientId, 'nest'),
            child: const Text('Disconnect',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ),
      );
    }

    if (!configured) {
      return Text(
        'Nest thermostat linking is not configured for this app build.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      );
    }

    if (_nestDevices != null) {
      // Step 3: pick the thermostat
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose the thermostat to use:'),
          const SizedBox(height: 8),
          if (_nestDevices!.isEmpty)
            const Text('No thermostats found on this Google account.')
          else
            ..._nestDevices!.map((d) => Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.home, color: AppTheme.primaryTeal),
                    title: Text(
                      d['displayName'] as String? ?? 'Thermostat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: d['tempF'] != null
                        ? Text(
                            'Currently ${(d['tempF'] as double).toStringAsFixed(0)}°F',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_busy,
                    onTap: () => _saveNest(patientId, d),
                  ),
                )),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _nestDevices = null;
                      _nestTokens = null;
                    }),
            child: const Text('Start over'),
          ),
        ],
      );
    }

    // Steps 1 + 2: sign in with Google, paste code
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uses the Nest thermostat already in the home — no extra '
          'hardware or batteries. Sign in with the Google account that '
          'owns the thermostat, then paste the code.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(NestApi.authorizeUrl(
                projectId: config.projectId,
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
            label: const Text('Open Google Sign-In'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nestCodeController,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Authorization code',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _validateNestCode,
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
      ],
    );
  }

  Future<void> _validateNestCode() async {
    final code = _nestCodeController.text.trim();
    if (code.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final config = ref.read(nestAppConfigProvider);
      final tokens = await NestApi.exchangeCode(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        redirectUri: config.redirectUri,
        code: code,
      ).timeout(const Duration(seconds: 20));
      final devices = await NestApi.listThermostats(
              tokens.accessToken, config.projectId)
          .timeout(const Duration(seconds: 20));
      setState(() {
        _nestTokens = tokens;
        _nestDevices = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify the code — check it was copied '
                'completely and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNest(String patientId, Map<String, dynamic> device) async {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    setState(() => _busy = true);
    try {
      await ref.read(environmentServiceProvider).saveNestLink(
            patientId,
            NestLink(
              refreshToken: _nestTokens!.refreshToken,
              deviceName: device['name'] as String,
              displayName: device['displayName'] as String?,
              connectedBy: caregiver?.id ?? '',
            ),
          );
      if (!mounted) return;
      setState(() {
        _nestDevices = null;
        _nestTokens = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nest thermostat connected')),
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

  // ── Shared ─────────────────────────────────────────────────────────────

  Future<void> _unlink(String patientId, String provider) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(environmentServiceProvider)
          .unlinkProvider(patientId, provider);
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
}

// ── Alert thresholds widget ───────────────────────────────────────────────

class _AlertThresholds extends ConsumerStatefulWidget {
  final String patientId;
  final EnvironmentAlertConfig config;
  const _AlertThresholds({required this.patientId, required this.config});

  @override
  ConsumerState<_AlertThresholds> createState() => _AlertThresholdsState();
}

class _AlertThresholdsState extends ConsumerState<_AlertThresholds> {
  late EnvironmentAlertConfig _config = widget.config;

  Future<void> _save() async {
    try {
      await ref
          .read(environmentServiceProvider)
          .saveAlertConfig(widget.patientId, _config);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save thresholds: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send alerts'),
              subtitle: const Text(
                'Notify caregivers when readings go out of range',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: _config.enabled,
              onChanged: (v) {
                setState(() => _config = _config.copyWith(enabled: v));
                _save();
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Temperature: ${_config.minTempF.toStringAsFixed(0)}°F – '
              '${_config.maxTempF.toStringAsFixed(0)}°F',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            RangeSlider(
              min: 40,
              max: 100,
              divisions: 60,
              values: RangeValues(
                _config.minTempF.clamp(40, 100).toDouble(),
                _config.maxTempF.clamp(40, 100).toDouble(),
              ),
              labels: RangeLabels(
                '${_config.minTempF.toStringAsFixed(0)}°F',
                '${_config.maxTempF.toStringAsFixed(0)}°F',
              ),
              onChanged: _config.enabled
                  ? (v) => setState(() => _config = _config.copyWith(
                      minTempF: v.start.roundToDouble(),
                      maxTempF: v.end.roundToDouble()))
                  : null,
              onChangeEnd: (_) => _save(),
            ),
            Text(
              'Humidity: ${_config.minHumidity.toStringAsFixed(0)}% – '
              '${_config.maxHumidity.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            RangeSlider(
              min: 0,
              max: 100,
              divisions: 100,
              values: RangeValues(
                _config.minHumidity.clamp(0, 100).toDouble(),
                _config.maxHumidity.clamp(0, 100).toDouble(),
              ),
              labels: RangeLabels(
                '${_config.minHumidity.toStringAsFixed(0)}%',
                '${_config.maxHumidity.toStringAsFixed(0)}%',
              ),
              onChanged: _config.enabled
                  ? (v) => setState(() => _config = _config.copyWith(
                      minHumidity: v.start.roundToDouble(),
                      maxHumidity: v.end.roundToDouble()))
                  : null,
              onChangeEnd: (_) => _save(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
