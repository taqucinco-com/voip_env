import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/signaling_client.dart';

// 疎通確認用の固定値。groupIdの選択UIは未実装。
// group_test1に所属する2つのuidのうち、ログイン中でない方を相手として扱う。
const _testGroupMemberUids = ['suyMIoEvFOVy2bBYvWhw4KZSQ753', 'yWo72LEq7TRiHRsPbfhzDh9Bzd13'];
const _testGroupId = 'group_test1';

String? _testCalleeUidFor(String? myUid) {
  return _testGroupMemberUids.where((uid) => uid != myUid).firstOrNull;
}

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

    Future<void> handleStartCall() async {
      final calleeUid = _testCalleeUidFor(user?.uid);
      final idToken = await authorizer.getIdToken();
      if (idToken == null || calleeUid == null) {
        return;
      }

      final result = await startCall(
        idToken: idToken,
        calleeUid: calleeUid,
        groupId: _testGroupId,
      );

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.statusCode}: ${result.body}')),
      );
    }

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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('user_id: ${user?.uid ?? '-'}'),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: handleStartCall,
              child: const Text('テスト発信 (start call)'),
            ),
          ],
        ),
      ),
    );
  }
}
