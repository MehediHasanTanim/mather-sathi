import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signs in anonymously if needed and returns the uid (task 0.4 smoke test).
/// Failures surface as an AsyncError; callers must not block app start on it.
final anonymousUidProvider = FutureProvider<String>((ref) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
  return user.uid;
});
