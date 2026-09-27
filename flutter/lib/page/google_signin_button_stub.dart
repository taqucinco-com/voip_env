import 'package:flutter/widgets.dart';

// Web専用実装(google_signin_button_web.dart)への差し替え先。
// 非Web環境でも呼ばれることはないが、条件付きインポートの解決には両方の
// ファイルにシンボルが必要。
Widget renderGoogleSignInButton() {
  throw UnsupportedError('renderGoogleSignInButton is only available on web');
}
