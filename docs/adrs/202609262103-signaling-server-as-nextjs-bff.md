# シグナリングAPIは独立したサーバーではなく管理画面Next.jsアプリのBFFとして実装する

## ステータス

承認済み（`docs/adrs/202609262054-call-signaling-via-backend-api.md`を一部supersede）

## コンテキスト

`docs/adrs/202609262054-call-signaling-via-backend-api.md`では、通話開始のシグナリングをクライアントの直接DB書き込みではなくバックエンドAPI経由にすることを決定した。当初はこのAPIサーバーをNode.js/Express等で実装し、将来の管理画面（Next.js）とは別のディレクトリ・別のサーバーとして構築する想定だった（`admin/`ディレクトリ）。

Next.jsはApp RouterのRoute HandlersによりBFF（Backend For Frontend）としてサーバー側処理を同一アプリ内に実装できる。管理画面自体も同じFirebaseプロジェクト・同じデータ構造（`groups`/`users`/`calls`）を扱うため、管理画面用のNext.jsアプリとシグナリングAPI用のバックエンドを別々に用意すると、Firebase Admin SDKの初期化やCoturnの共有シークレット管理などを二重に持つことになる。

## 決定

シグナリングAPI（`POST /api/calls/start`等）は、独立したExpressサーバーではなく、管理画面用に作成したNext.jsアプリのRoute Handlersとして実装する。これに伴い、ディレクトリ名を`admin`から`signaling`に変更する。

`docker-compose.yml`上のサービス名も`admin`から`signaling`に変更し、このコンテナが「管理画面」と「シグナリングBFF」の両方の役割を持つことを名前で表す。

## 理由

- Next.jsのRoute Handlersを使えば、管理画面と同じプロジェクト・同じデプロイ単位でサーバー処理を実装でき、Firebase Admin SDKの初期化処理やCoturnとの共有シークレットの管理を1箇所に集約できる
- 管理画面自体も通話ログやユーザー状態の確認・操作でFirebase Realtime Databaseに同じくサーバー権限でアクセスする必要があり、アクセス経路を分ける理由が薄い
- サーバーを1つに集約することで、開発環境（docker-compose）・デプロイ対象が1つ減り、運用の複雑さが下がる

## 影響・トレードオフ

- シグナリングAPIと管理画面が同じNext.jsアプリ・同じデプロイ単位になるため、片方の変更がもう片方の可用性に影響しうる（例: 管理画面のビルドエラーがシグナリングAPIの停止に直結する）
- 将来的にシグナリングAPIの負荷が管理画面と大きく異なる特性を持つ場合（例: 同時接続数の急増）、スケーリング単位を分けたくなる可能性がある。その場合は改めてサーバー分離を検討する
- `docs/adrs/202609262054-call-signaling-via-backend-api.md`にある「バックエンドAPIサーバー」という記述は、実装先がNext.js Route Handlersに変わったものとして読み替える
