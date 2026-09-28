// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incoming_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IncomingCall _$IncomingCallFromJson(Map<String, dynamic> json) => IncomingCall(
  roomId: json['roomId'] as String,
  callerUid: json['callerUid'] as String,
  groupId: json['groupId'] as String,
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, dynamic> _$IncomingCallToJson(IncomingCall instance) =>
    <String, dynamic>{
      'roomId': instance.roomId,
      'callerUid': instance.callerUid,
      'groupId': instance.groupId,
      'createdAt': instance.createdAt,
    };
