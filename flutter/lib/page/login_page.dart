import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';

// google_sign_in_webはdart:js_interopに依存しており、非Web(Android/iOS)の
// kernelコンパイルに含めると型解決エラーになるため、条件付きインポートで
// 非Web環境ではstub実装に差し替える。
import 'google_signin_button_web.dart'
    if (dart.library.io) 'google_signin_button_stub.dart'
    as google_signin_button;

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authFacade = ref.watch(authFacadeProvider);

    // Web版のGoogle Identity Servicesはauthenticate()による明示的な呼び出しに
    // 対応しないため、公式ボタン(renderButton)のクリックをauthenticationEventsで受け取る。
    useEffect(() {
      if (!kIsWeb) return null;
      final subscription = GoogleSignIn.instance.authenticationEvents.listen((
        event,
      ) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          authFacade.signInWithGoogleAccount(event.user);
        }
      });
      return subscription.cancel;
    }, [authFacade]);

    final googleSignInButton = kIsWeb
        ? google_signin_button.renderGoogleSignInButton()
        : ElevatedButton.icon(
            onPressed: () async => await authFacade.signInWithGoogle(),
            icon: const Icon(Icons.login),
            label: const Text('Googleでログイン'),
          );

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ログインが必要です',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              googleSignInButton,
            ],
          ),
        ),
      ),
    );
  }
}
