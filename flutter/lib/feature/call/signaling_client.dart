import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

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

Future<SignalingApiResult> _post({
  required String path,
  required String idToken,
  Map<String, dynamic>? body,
}) async {
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

Future<SignalingApiResult> startCall({
  required String idToken,
  required String calleeUid,
  required String groupId,
}) {
  return _post(
    path: '/api/calls/start',
    idToken: idToken,
    body: {'calleeUid': calleeUid, 'groupId': groupId},
  );
}

Future<SignalingApiResult> acceptCall({
  required String idToken,
  required String roomId,
}) {
  return _post(path: '/api/calls/$roomId/accept', idToken: idToken);
}

Future<SignalingApiResult> endCall({
  required String idToken,
  required String roomId,
}) {
  return _post(path: '/api/calls/$roomId/end', idToken: idToken);
}
