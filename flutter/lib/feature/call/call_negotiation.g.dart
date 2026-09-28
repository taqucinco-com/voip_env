// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_negotiation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SdpMessage _$SdpMessageFromJson(Map<String, dynamic> json) => SdpMessage(
  sdp: json['sdp'] as String,
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, dynamic> _$SdpMessageToJson(SdpMessage instance) =>
    <String, dynamic>{'sdp': instance.sdp, 'createdAt': instance.createdAt};

IceCandidateEntry _$IceCandidateEntryFromJson(Map<String, dynamic> json) =>
    IceCandidateEntry(
      candidate: json['candidate'] as String,
      sdpMid: json['sdpMid'] as String?,
      sdpMLineIndex: (json['sdpMLineIndex'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
    );

Map<String, dynamic> _$IceCandidateEntryToJson(IceCandidateEntry instance) =>
    <String, dynamic>{
      'candidate': instance.candidate,
      'sdpMid': instance.sdpMid,
      'sdpMLineIndex': instance.sdpMLineIndex,
      'createdAt': instance.createdAt,
    };
