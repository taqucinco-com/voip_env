import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/signaling_client.dart';

final signalingClientProvider = Provider.autoDispose<SignalingClient>((ref) {
  return SignalingClientImpl(
    authorizationFacade: ref.read(authFacadeProvider),
  );
});
