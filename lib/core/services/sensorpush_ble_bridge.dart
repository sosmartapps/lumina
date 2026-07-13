import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Patient-phone Bluetooth bridge to a SensorPush 2nd-generation sensor
/// (HT.w / HTP.xw) — the phone acts as the "gateway" so no G1 WiFi
/// Gateway is needed.
///
/// Direct port of So Smart Scans `SensorPushManager.swift` (SensorPush
/// "Bluetooth Protocol for 2nd Generation Sensor Devices"):
///  • Service  EF090000-11D6-42BA-93B8-9DD7EC090AB0
///  • Temp     EF090080-…AA9 — write any 4 bytes to trigger a fresh
///    sensor read, then read back Int32 (little-endian) in hundredths
///    of °C. This read also refreshes humidity on-device.
///  • Humidity EF090081-…AA9 — Int32 (little-endian) hundredths of % RH.
///
/// Lifecycle: `start(patientId)` watches `environment_connections/
/// {patientId}`; when `ble.enabled` is true it scans (SensorPush doesn't
/// reliably advertise its service UUID, so match by name prefix), keeps
/// the connection open, samples every [readInterval], and writes each
/// reading to Firestore — history subcollection + `latest` — where the
/// caregiver dashboard and the alert trigger pick it up.
class SensorPushBleBridge {
  static const String _serviceUuid = 'ef090000-11d6-42ba-93b8-9dd7ec090ab0';
  static const String _tempCharUuid = 'ef090080-11d6-42ba-93b8-9dd7ec090aa9';
  static const String _humCharUuid = 'ef090081-11d6-42ba-93b8-9dd7ec090aa9';

  static const Duration readInterval = Duration(minutes: 15);
  static const Duration _scanTimeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(minutes: 2);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _patientId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _connSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _tempChar;
  BluetoothCharacteristic? _humChar;
  Timer? _readTimer;
  Timer? _retryTimer;
  bool _enabled = false;
  bool _busy = false;

  /// Watch the patient's environment connection and run the bridge
  /// whenever the caregiver has BLE enabled. Safe to call once at splash.
  void start(String patientId) {
    _patientId = patientId;
    _connSub?.cancel();
    _connSub = _firestore
        .collection('environment_connections')
        .doc(patientId)
        .snapshots()
        .listen((doc) {
      final enabled =
          doc.exists && (doc.data()?['ble']?['enabled'] == true);
      if (enabled && !_enabled) {
        _enabled = true;
        _connect();
      } else if (!enabled && _enabled) {
        _enabled = false;
        _teardownDevice();
      }
    }, onError: (e) => debugPrint('EnvBLE: connection watch error: $e'));
  }

  Future<void> dispose() async {
    _enabled = false;
    await _connSub?.cancel();
    _connSub = null;
    _teardownDevice();
  }

  // ── Connection ───────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (!_enabled || _busy) return;
    _busy = true;
    try {
      // Wait for the adapter (also surfaces the iOS permission prompt).
      final adapterState = await FlutterBluePlus.adapterState
          .where((s) =>
              s == BluetoothAdapterState.on ||
              s == BluetoothAdapterState.unauthorized)
          .first
          .timeout(const Duration(seconds: 20));
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('EnvBLE: bluetooth unavailable ($adapterState)');
        _scheduleRetry();
        return;
      }

      debugPrint('EnvBLE: scanning for SensorPush…');
      BluetoothDevice? found;
      final completer = Completer<BluetoothDevice?>();
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          if (name.startsWith('SensorPush') && !completer.isCompleted) {
            completer.complete(r.device);
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: _scanTimeout);
      found = await completer.future
          .timeout(_scanTimeout, onTimeout: () => null);
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

      if (found == null) {
        debugPrint('EnvBLE: no SensorPush found — retrying later');
        _scheduleRetry();
        return;
      }
      if (!_enabled) return;

      final name =
          found.platformName.isNotEmpty ? found.platformName : 'SensorPush';
      debugPrint('EnvBLE: connecting to $name');
      await found.connect(timeout: const Duration(seconds: 15));
      _device = found;

      // Reconnect automatically if the sensor drops.
      _deviceStateSub?.cancel();
      _deviceStateSub = found.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _enabled) {
          debugPrint('EnvBLE: disconnected — will reconnect');
          _teardownDevice(keepEnabled: true);
          _scheduleRetry();
        }
      });

      final services = await found.discoverServices();
      final svc = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == _serviceUuid,
        orElse: () => throw Exception('SensorPush service not found'),
      );
      for (final c in svc.characteristics) {
        final id = c.uuid.str128.toLowerCase();
        if (id == _tempCharUuid) _tempChar = c;
        if (id == _humCharUuid) _humChar = c;
      }
      if (_tempChar == null) throw Exception('temp characteristic missing');

      // Record the sensor name for the caregiver UI.
      await _connectionDoc?.set({
        'ble': {'sensorName': name},
      }, SetOptions(merge: true));

      debugPrint('EnvBLE: connected — starting reads');
      await _readAndPublish();
      _readTimer?.cancel();
      _readTimer = Timer.periodic(readInterval, (_) => _readAndPublish());
    } catch (e) {
      debugPrint('EnvBLE: connect failed: $e');
      _teardownDevice(keepEnabled: true);
      _scheduleRetry();
    } finally {
      _busy = false;
    }
  }

  void _scheduleRetry() {
    if (!_enabled) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (_enabled && _device == null) _connect();
    });
  }

  void _teardownDevice({bool keepEnabled = false}) {
    _readTimer?.cancel();
    _readTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    _deviceStateSub?.cancel();
    _deviceStateSub = null;
    final d = _device;
    _device = null;
    _tempChar = null;
    _humChar = null;
    if (d != null) {
      d.disconnect().catchError((_) {});
    }
    if (!keepEnabled) FlutterBluePlus.stopScan().catchError((_) {});
  }

  // ── Reading ──────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _connectionDoc =>
      _patientId == null
          ? null
          : _firestore.collection('environment_connections').doc(_patientId);

  Future<void> _readAndPublish() async {
    final tempChar = _tempChar;
    final patientId = _patientId;
    if (tempChar == null || patientId == null || !_enabled) return;
    try {
      // Any 4-byte write triggers a fresh on-device sample.
      await tempChar.write(const [0x01, 0x00, 0x00, 0x00],
          withoutResponse: false);
      final tempRaw = await tempChar.read();
      final tempC = _hundredths(tempRaw);
      if (tempC == null) throw Exception('bad temperature data');

      double? humidity;
      if (_humChar != null) {
        final humRaw = await _humChar!.read();
        humidity = _hundredths(humRaw);
      }

      final tempF = tempC * 9 / 5 + 32;
      final now = Timestamp.now();
      debugPrint(
          'EnvBLE: read ${tempF.toStringAsFixed(1)}°F / ${humidity?.toStringAsFixed(0)}%');

      final doc = await _connectionDoc!.get();
      final sensorName = doc.data()?['ble']?['sensorName'] ?? 'SensorPush';

      await _firestore
          .collection('users')
          .doc(patientId)
          .collection('environment_readings')
          .add({
        'provider': 'ble',
        'sensorName': sensorName,
        'tempF': tempF,
        'humidity': humidity ?? 0,
        'timestamp': now,
      });
      await _connectionDoc!.set({
        'latest': {
          'tempF': tempF,
          'humidity': humidity ?? 0,
          'observedAt': now,
          'provider': 'ble',
          'sensorName': sensorName,
        },
        'ble': {'lastSeenAt': now},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('EnvBLE: read failed: $e');
    }
  }

  /// SensorPush values are Int32 little-endian in hundredths of a unit.
  static double? _hundredths(List<int> data) {
    if (data.length < 4) return null;
    final raw = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
    final signed = raw.toSigned(32);
    return signed / 100.0;
  }
}
