import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Handles deep links for invite codes and other app links.
///
/// Supports:
/// - https://lumina.app/invite?code=XXXXXX
/// - lumina://invite?code=XXXXXX
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Invite code from the initial link that opened the app (if any).
  String? pendingInviteCode;

  /// Stream controller for invite codes received while the app is running.
  final _inviteCodeController = StreamController<String>.broadcast();
  Stream<String> get inviteCodeStream => _inviteCodeController.stream;

  Future<void> initialize() async {
    // Check if app was opened via a deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        final code = _extractInviteCode(initialUri);
        if (code != null) {
          pendingInviteCode = code;
        }
      }
    } catch (e) {
      debugPrint('Deep link initial check failed: $e');
    }

    // Listen for subsequent deep links while app is running
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      final code = _extractInviteCode(uri);
      if (code != null) {
        _inviteCodeController.add(code);
      }
    });
  }

  String? _extractInviteCode(Uri uri) {
    // Handle: https://lumina.app/invite?code=XXXXXX
    // Handle: lumina://invite?code=XXXXXX
    final isInvitePath = uri.path == '/invite' || uri.host == 'invite';
    if (isInvitePath) {
      final code = uri.queryParameters['code'];
      if (code != null && code.length == 6) {
        return code.toUpperCase();
      }
    }
    return null;
  }

  /// Clear the pending invite code after it's been consumed.
  void clearPendingInviteCode() {
    pendingInviteCode = null;
  }

  void dispose() {
    _subscription?.cancel();
    _inviteCodeController.close();
  }
}
