import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

// AndroidエミュレータからはホストのDockerコンテナへ`localhost`で到達できないため、
// エミュレータ専用のループバックアドレス`10.0.2.2`を使う。
// https://developer.android.com/studio/run/emulator-networking
String _signalingBaseUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

class StartCallResult {
  StartCallResult({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

Future<StartCallResult> startCall({
  required String idToken,
  required String calleeUid,
  required String groupId,
}) async {
  final response = await http.post(
    Uri.parse('${_signalingBaseUrl()}/api/calls/start'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'calleeUid': calleeUid, 'groupId': groupId}),
  );

  return StartCallResult(
    statusCode: response.statusCode,
    body: jsonDecode(response.body) as Map<String, dynamic>,
  );
}
