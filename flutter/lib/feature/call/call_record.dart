import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:json_annotation/json_annotation.dart';

part 'call_record.g.dart';

@JsonSerializable()
class CallRecord {
  const CallRecord({
    required this.caller,
    required this.callee,
    required this.status,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) =>
      _$CallRecordFromJson(json);

  // RTDBのsnapshot.valueはMap<Object?, Object?>で返るため、
  // fromJsonが要求するMap<String, dynamic>へ変換してから渡す。
  factory CallRecord.fromSnapshotValue(Object value) =>
      CallRecord.fromJson(Map<String, dynamic>.from(value as Map));

  final String caller;
  final String callee;
  final String status; // "calling" | "active" | "ended"

  Map<String, dynamic> toJson() => _$CallRecordToJson(this);
}

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
