# 通話シグナリングはクライアントの直接DB書き込みではなくバックエンドAPI経由にする

## ステータス

`docs/adrs/202609262103-signaling-server-as-nextjs-bff.md` により一部supersede済み（バックエンドAPIをクライアントの直接DB書き込みの代わりに置く、という決定自体は有効。ただしそのAPIを独立したNode.js/Expressサーバーではなく、管理画面と同じNext.jsアプリのBFFとして実装する方針に変更）

## コンテキスト

WebRTCの通話開始シグナリングにはFirebase Realtime Databaseを使う（README参照）。実装方針として、クライアント（発信者）がFirebase Realtime Databaseへ直接書き込んで通話ルームを作る方式と、クライアントはバックエンドAPI（Node.js/Express等）にリクエストし、APIがサーバー権限（Firebase Admin SDK）でDBへ書き込む方式の2通りが考えられる。

以下の検証・制御は、Realtime DatabaseのセキュリティルールだけではAPIレスポンスとして表現しづらく、また複数ステップにまたがる処理のため、クライアント側の直接書き込みでは実現が難しい。

- 発信者と着信者が同じグループに所属しているかの確認
- 着信者が既に通話中（`busy`）かどうかのチェックと、その場合の即時拒否
- 通話ルーム作成・着信通知の書き込み・双方のステータス更新を一連の処理として扱うこと
- Coturn（TURN/STUNサーバー）の時限認証トークン（`static-auth-secret`によるHMAC-SHA1署名）の発行

## 決定

通話開始はクライアントがFirebase Realtime Databaseに直接書き込むのではなく、必ずバックエンドAPI（`POST /api/calls/start`）を経由する。

### データ構造

```json
{
  "groups": {
    "group_101": {
      "members": { "uid_userA": true, "uid_userB": true }
    }
  },
  "users": {
    "uid_userA": { "status": "online" },
    "uid_userB": { "status": "online" }
  },
  "calls": {
    "room_xyz123": {
      "groupId": "group_101",
      "caller": "uid_userA",
      "callee": "uid_userB",
      "status": "calling",
      "createdAt": 1710000000
    }
  }
}
```

- `groups/{groupId}/members`: グループ所属ユーザーの一覧。発信者・着信者双方がここに含まれることを発信可否の条件とする
- `users/{uid}/status`: `online` / `busy`。着信者が`busy`の場合はAPIが`409`を返して即座に拒否する
- `users/{uid}/incomingCall`: 着信通知バッファ。着信者クライアントはこのノードを監視（`onValue`）し、着信ダイアログを表示する
- `calls/{roomId}`: 通話セッションの状態と、Offer/Answer/ICE Candidateの受け渡し場所

### API処理フロー（`POST /api/calls/start`）

1. `Authorization: Bearer <idToken>`をFirebase Admin SDKで検証し、発信者UIDを確定する
2. 発信者・着信者が同一グループ（`groupId`）に所属しているか確認する
3. 着信者のステータスが`busy`でないか確認する
4. `calls`配下に新規`roomId`でセッションを作成する
5. 着信者の`incomingCall`ノードに`roomId`・発信者UID・`groupId`を書き込む
6. 発信者のステータスを`busy`に更新する
7. Coturnの共有シークレットでTURN時限認証情報（`username`/`credential`）を生成する
8. `roomId`と`iceServers`（STUN/TURNサーバー情報）をレスポンスとして返す

以降のOffer/Answer/ICE Candidateの交換は、発行された`roomId`を使ってクライアント同士が`calls/{roomId}`配下に直接読み書きする。

## 理由

- 認可されていないユーザーの通話リクエストを、シグナリング用DBノードが作られる前段階でAPIが遮断できる
- 着信者が通話中かどうかのチェックを、WebRTCの重い処理（Offer/Answer/ICE収集）を始める前に行える
- TURN資格情報の発行をFirebase ID Tokenの検証と同一トランザクションに統合できるため、「認証済みユーザーにのみ時限トークンを渡す」という制約を1箇所で保証できる
- 通話終了・ステータス復帰などの後続処理も同じAPI層に集約でき、DB直接操作より制御ロジックの置き場所が一元化される

## 影響・トレードオフ

- `admin`（管理画面）や各クライアントアプリとは別に、通話開始APIを提供するバックエンドサーバー（Node.js/Express等）の実装・運用が必要になる
- Firebase Admin SDKの認証情報（サービスアカウント）と、Coturnとの共有シークレット（`TURN_SECRET`）の両方をこのAPIサーバーが安全に保持する必要がある
- Offer/Answer/ICE Candidateの交換自体は引き続きクライアントからRealtime Databaseへの直接読み書きで行うため、Realtime Database側のセキュリティルールで「`calls/{roomId}`はcaller/calleeのみ読み書き可」といった制限も別途必要になる
