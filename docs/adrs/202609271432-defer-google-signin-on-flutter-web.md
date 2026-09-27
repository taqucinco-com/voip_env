# Flutter WebでのGoogleログインは開発用ポートを固定して登録する

## ステータス

対応済み

## コンテキスト

`lib/feature/auth`配下にriverpod（`hooks_riverpod`）とhooksを用いてGoogleログイン機能を実装し、`lib/page/login_page.dart`・`lib/page/home_page.dart`からAndroidで動作確認済みである。

Flutter Webでも同じログイン画面を表示できるよう、`google_sign_in`パッケージ（v7系API）のWeb実装に合わせて以下の分岐を用意した。

- モバイル: `GoogleSignIn.instance.authenticate()`を独自ボタンから呼び出す
- Web: `google_sign_in_web`が提供するGoogle Identity Services公式ボタン（`renderButton`）を表示し、そのクリックによる認証結果を`GoogleSignIn.instance.authenticationEvents`ストリームで受け取る

この状態で`flutter run -d chrome`から実際にログインを試みたところ、Googleの認証画面で次のエラーが表示された。

> アクセスをブロック: 認証エラーです。このアプリはGoogleのOAuth 2.0ポリシーを遵守していないため、ログインできません。このアプリのデベロッパーの方は、Google Cloud ConsoleでJavaScriptオリジンを登録してください。

これはFlutter側の実装の問題ではなく、Google Cloud Console上のOAuth 2.0 Webクライアントに、リクエスト元オリジン（例: `http://localhost:<port>`）が「承認済みのJavaScript生成元」として登録されていないために発生する。`flutter run -d chrome`はデフォルトでは起動のたびに異なるポートを使うため、ポートを固定しない限りGoogle Cloud Console側での登録が成立しない。

なお、この登録はFirebase Console（`console.firebase.google.com`）の「Authentication → Settings → 承認済みドメイン」ではなく、Google Cloud Console（`console.cloud.google.com/apis/credentials`）側のOAuth 2.0クライアントID（Webクライアント）の「承認済みの JavaScript 生成元」欄で行う。前者はドメイン名のみを受け付ける別機能で、`http://`やポート番号を含む値は登録できない。

## 決定

ローカル開発でFlutter Webを動かす際のポートを`5000`に固定し、Google Cloud ConsoleのOAuth 2.0 Webクライアントの「承認済みの JavaScript 生成元」に`http://localhost:5000`を登録した。

`.vscode/launch.json`の「flutter voip_env (Chrome)」構成に`"args": ["--web-port", "5000"]`を設定し、CLIから起動する場合も`flutter run -d chrome --web-port 5000`でポートを固定する。

`lib/page/login_page.dart`の`kIsWeb`分岐によるWeb向け実装（`renderButton`表示、`authenticationEvents`購読）はそのまま使用する。

## 理由

- Google Identity Servicesの認証は、リクエスト元オリジンがOAuth 2.0クライアントの「承認済みの JavaScript 生成元」に完全一致で登録されている必要があり、ポートも含めて一致させる必要がある
- 開発用ポートを`5000`に固定することで、`flutter run -d chrome`を実行するたびにポートが変わって都度登録し直す事態を避けられる

## 影響・トレードオフ

- ローカルでFlutter Webを起動する際は、必ず`--web-port 5000`（または`.vscode/launch.json`の「flutter voip_env (Chrome)」構成）を使う必要がある。別ポートで起動すると同じ「JavaScriptオリジン未登録」エラーが再発する
- 本番でWebを配信するドメインが決まった際は、そのオリジンも別途「承認済みの JavaScript 生成元」に追加登録する必要がある
