import 'package:json_annotation/json_annotation.dart';

part 'call_negotiation.g.dart';

@JsonSerializable()
class SdpMessage {
  const SdpMessage({required this.sdp, required this.createdAt});

  factory SdpMessage.fromJson(Map<String, dynamic> json) =>
      _$SdpMessageFromJson(json);

  factory SdpMessage.fromSnapshotValue(Object value) =>
      SdpMessage.fromJson(Map<String, dynamic>.from(value as Map));

  final String sdp;
  final int createdAt;

  Map<String, dynamic> toJson() => _$SdpMessageToJson(this);
}

@JsonSerializable()
class IceCandidateEntry {
  const IceCandidateEntry({
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
    required this.createdAt,
  });

  factory IceCandidateEntry.fromJson(Map<String, dynamic> json) =>
      _$IceCandidateEntryFromJson(json);

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final int createdAt;

  Map<String, dynamic> toJson() => _$IceCandidateEntryToJson(this);
}

// roomIdの通話交渉（offer/answer/ICE候補の交換）の現在状態。
typedef CallNegotiationState = ({
  SdpMessage? offer,
  SdpMessage? answer,
  List<IceCandidateEntry> callerIceCandidates,
  List<IceCandidateEntry> calleeIceCandidates,
});
