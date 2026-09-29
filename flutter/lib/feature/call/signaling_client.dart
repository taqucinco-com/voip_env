import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:voip_env/feature/auth/auth_facade.dart';

// AndroidエミュレータからはホストのDockerコンテナへ`localhost`で到達できないため、
// エミュレータ専用のループバックアドレス`10.0.2.2`を使う。
// https://developer.android.com/studio/run/emulator-networking
String? host = '10.6.3.36';
// String? host = null;

String _signalingBaseUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://${host ?? '10.0.2.2'}:3000';
  }
  return 'http://${host ?? 'localhost'}:3000';
}

class SignalingApiResult {
  SignalingApiResult({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class SignalingClient {
  Future<SignalingApiResult> startCall({
    required String calleeUid,
    required String groupId,
  });

  Future<SignalingApiResult> acceptCall({required String roomId});

  Future<SignalingApiResult> endCall({required String roomId});

  Future<SignalingApiResult> submitOffer({
    required String roomId,
    required String sdp,
  });

  Future<SignalingApiResult> submitAnswer({
    required String roomId,
    required String sdp,
  });

  Future<SignalingApiResult> submitIceCandidate({
    required String roomId,
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  });
}

class SignalingClientImpl implements SignalingClient {
  SignalingClientImpl({required AuthorizationFacade authorizationFacade})
    : _authorizationFacade = authorizationFacade;

  final AuthorizationFacade _authorizationFacade;

  Future<SignalingApiResult> _post({
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final idToken = await _authorizationFacade.getIdToken();
    if (idToken == null) {
      throw StateError('idToken is not available. User is not signed in.');
    }

    final response = await http.post(
      Uri.parse('${_signalingBaseUrl()}$path'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );

    debugPrint(
      'Signaling API response ($path): ${response.statusCode} ${response.body}',
    );

    return SignalingApiResult(
      statusCode: response.statusCode,
      body: jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<SignalingApiResult> startCall({
    required String calleeUid,
    required String groupId,
  }) {
    return _post(
      path: '/api/calls/start',
      body: {'calleeUid': calleeUid, 'groupId': groupId},
    );
  }

  @override
  Future<SignalingApiResult> acceptCall({required String roomId}) {
    return _post(path: '/api/calls/$roomId/accept');
  }

  @override
  Future<SignalingApiResult> endCall({required String roomId}) {
    return _post(path: '/api/calls/$roomId/end');
  }

  @override
  Future<SignalingApiResult> submitOffer({
    required String roomId,
    required String sdp,
  }) {
    return _post(path: '/api/calls/$roomId/offer', body: {'sdp': sdp});
  }

  @override
  Future<SignalingApiResult> submitAnswer({
    required String roomId,
    required String sdp,
  }) {
    return _post(path: '/api/calls/$roomId/answer', body: {'sdp': sdp});
  }

  @override
  Future<SignalingApiResult> submitIceCandidate({
    required String roomId,
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    return _post(
      path: '/api/calls/$roomId/ice-candidates',
      body: {
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      },
    );
  }
}
