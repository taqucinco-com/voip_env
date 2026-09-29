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
