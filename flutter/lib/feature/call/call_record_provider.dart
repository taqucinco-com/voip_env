import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/call/call_record.dart';

// calls/{roomId}を監視する。database.rules.jsonで.readはcaller/callee本人に
// 限定されているため、roomIdを知っている＝自分がその通話の参加者であることが前提。
final callRecordProvider = StreamProvider.autoDispose
    .family<CallRecord?, String>((ref, roomId) {
      final callRef = FirebaseDatabase.instance.ref('calls/$roomId');
      return callRef.onValue.map((event) {
        final value = event.snapshot.value;
        if (value == null) {
          return null;
        }
        return CallRecord.fromSnapshotValue(value);
      });
    });
