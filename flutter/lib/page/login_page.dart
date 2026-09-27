import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';

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
        ? google_sign_in_web.renderButton()
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
