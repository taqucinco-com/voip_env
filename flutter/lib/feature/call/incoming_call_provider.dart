import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/incoming_call.dart';

// 自分（callee）のuid配下のincomingCallのみ監視する。database.rules.jsonでも
// users/{uid}/incomingCallの読み取りは本人（auth.uid === $uid）に限定されている。
final incomingCallProvider = StreamProvider.autoDispose<IncomingCall?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value(null);
  }

  final incomingCallRef = FirebaseDatabase.instance.ref(
    'users/${user.uid}/incomingCall',
  );
  return incomingCallRef.onValue.map((event) {
    final value = event.snapshot.value;
    if (value == null) {
      return null;
    }
    return IncomingCall.fromSnapshotValue(value);
  });
});
