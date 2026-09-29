import 'package:json_annotation/json_annotation.dart';

part 'incoming_call.g.dart';

@JsonSerializable()
class IncomingCall {
  const IncomingCall({
    required this.roomId,
    required this.callerUid,
    required this.groupId,
    required this.createdAt,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> json) =>
      _$IncomingCallFromJson(json);

  factory IncomingCall.fromSnapshotValue(Object value) =>
      IncomingCall.fromJson(Map<String, dynamic>.from(value as Map));

  final String roomId;
  final String callerUid;
  final String groupId;
  final int createdAt;

  Map<String, dynamic> toJson() => _$IncomingCallToJson(this);
}
