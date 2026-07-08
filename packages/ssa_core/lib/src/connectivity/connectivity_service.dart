import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity state for any SSA app.
///
/// Wraps connectivity_plus to provide a simple boolean online/offline state
/// and a stream that apps can react to.
class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final online = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  /// Check current connectivity (useful on app startup).
  Future<bool> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    return _isOnline;
  }

  /// Dispose the connectivity listener.
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
