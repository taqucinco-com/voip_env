import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final authorizer = ref.watch(authFacadeProvider);

    useEffect(() {
      Future.microtask(() async {
        final idToken = await authorizer.getIdToken();
        debugPrint('ID Token: $idToken');
      });
      return null;
    }, [user]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async => await ref.read(authFacadeProvider).signOut(),
          ),
        ],
      ),
      body: Center(child: Text('user_id: ${user?.uid ?? '-'}')),
    );
  }
}
