import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_facade.dart';

final authStateChangesProvider = StreamProvider.autoDispose<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authFacadeProvider = Provider.autoDispose<AuthorizationFacade>((ref) {
  return AuthorizationFacadeImpl();
});
