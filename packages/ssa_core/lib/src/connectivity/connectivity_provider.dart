import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

/// Provides the shared [ConnectivityService] instance.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Streams connectivity changes as a boolean (true = online).
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});
