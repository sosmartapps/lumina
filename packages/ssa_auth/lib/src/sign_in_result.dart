import 'package:firebase_auth/firebase_auth.dart';

/// Result of a sign-in attempt that may require MFA verification.
///
/// Check [requiresMfa] before accessing [credential] or [resolver].
class SignInResult {
  const SignInResult.success(this.credential)
      : resolver = null,
        requiresMfa = false;

  const SignInResult.mfaRequired(this.resolver)
      : credential = null,
        requiresMfa = true;

  /// The Firebase credential (available when MFA is not required).
  final UserCredential? credential;

  /// The MFA resolver (available when TOTP verification is needed).
  final MultiFactorResolver? resolver;

  /// Whether this sign-in requires a second factor.
  final bool requiresMfa;
}
