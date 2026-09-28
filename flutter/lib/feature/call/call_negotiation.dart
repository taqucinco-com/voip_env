import 'package:firebase_database/firebase_database.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

// calls/{roomId}/offerを監視する。offerはcaller本人のみAPI経由で書き込める
// （database.rules.jsonでは.write: false、submitOffer()がAdmin SDKで書き込む）。
final callOfferProvider = StreamProvider.autoDispose.family<SdpMessage?, String>((
  ref,
  roomId,
) {
  final offerRef = FirebaseDatabase.instance.ref('calls/$roomId/offer');
  return offerRef.onValue.map((event) {
    final value = event.snapshot.value;
    if (value == null) {
      return null;
    }
    return SdpMessage.fromSnapshotValue(value);
  });
});

// calls/{roomId}/answerを監視する。answerはcallee本人のみAPI経由で書き込める。
final callAnswerProvider = StreamProvider.autoDispose
    .family<SdpMessage?, String>((ref, roomId) {
      final answerRef = FirebaseDatabase.instance.ref('calls/$roomId/answer');
      return answerRef.onValue.map((event) {
        final value = event.snapshot.value;
        if (value == null) {
          return null;
        }
        return SdpMessage.fromSnapshotValue(value);
      });
    });

typedef IceCandidatesQuery = ({String roomId, String side});

// calls/{roomId}/iceCandidates/{side}（side: "caller" | "callee"）を監視する。
// pushで追記されるリストなので、受信済みのICE candidateを古い順のリストで返す。
final iceCandidatesProvider = StreamProvider.autoDispose
    .family<List<IceCandidateEntry>, IceCandidatesQuery>((ref, query) {
      final candidatesRef = FirebaseDatabase.instance.ref(
        'calls/${query.roomId}/iceCandidates/${query.side}',
      );
      return candidatesRef.onValue.map((event) {
        final value = event.snapshot.value;
        if (value == null) {
          return const <IceCandidateEntry>[];
        }
        final map = Map<Object?, Object?>.from(value as Map);
        return map.values
            .map(
              (entry) => IceCandidateEntry.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .toList();
      });
    });
