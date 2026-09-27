# 通話ルームのスキーマとシグナリングAPIのエンドポイント構成を確定する

## ステータス

承認済み（`docs/adrs/202609262054-call-signaling-via-backend-api.md`の`calls/{roomId}`スキーマ・API設計を補完・具体化）

## コンテキスト

`docs/adrs/202609262054-call-signaling-via-backend-api.md`で、通話開始をバックエンドAPI経由にすることと、`groups/users/calls`という大枠のスキーマは決定済みだった。しかし以下は未確定だった。

- `calls/{roomId}`配下にOffer/Answer/ICE Candidateをどう格納するか
- 着信への応答（accept/reject）・通話終了（cancel/hangup）をAPIとしてどう用意するか
- Offer/Answer/ICE Candidateの交換もAPI経由にすべきか、クライアントの直接RTDB読み書きのままにすべきか

`signaling/`は`create-next-app`直後の状態で、Route Handlerを1本も持っていなかった。

## 決定

### `calls/{roomId}`のステータスを3値に集約する

`calling`→`active`→`ended`の3状態のみとし、終了理由（拒否/発信取消/通話終了）はステータスを分けず`endedReason`(`"rejected"|"cancelled"|"hangup"`)と`endedBy`(uid)という別フィールドで表現する。理由はいずれも「通話が終わった」という同じ状態であり、遷移元のステータス（`calling`/`active`）と操作者（caller/callee）から一意に導出できるため、ステータス自体を乱立させない。

```jsonc
"calls": {
  "room_xyz123": {
    "groupId": "group_101", "caller": "uid_A", "callee": "uid_B",
    "status": "calling",              // "calling" | "active" | "ended"
    "endedReason": null, "endedBy": null,
    "createdAt": 0, "answeredAt": null, "endedAt": null,
    "offer": { "sdp": "...", "createdAt": 0 },
    "answer": { "sdp": "...", "createdAt": 0 },
    "iceCandidates": {
      "caller": { "-pushKey": { "candidate": "...", "sdpMid": "0", "sdpMLineIndex": 0, "createdAt": 0 } },
      "callee": { "-pushKey": { "...": "..." } }
    }
  }
}
```

`offer`/`answer`は単一フィールド（再交渉なしの1:1音声通話のため）。ICE Candidateは`push()`キーによる追記専用リストを送信者ごと（`caller`/`callee`）に分離する。trickle ICEは高頻度の追記であり単一フィールドだと上書き競合するのと、送信者ごとに分けることでセキュリティルールが「callerは`caller`配下だけ書ける」と単純に表現できるため。

### APIは3本（`start`/`accept`/`end`）とし、accept/reject/cancel/hangupを`end`1本に統合する

- `POST /api/calls/start`: caller。グループ所属確認・busy判定・`calls`へのpushによるroomId発行・`users/{callee}/incomingCall`書き込み・TURN時限資格情報の発行を行う
- `POST /api/calls/[roomId]/accept`: callee。`status`を`calling`→`active`へ遷移させ、TURN資格情報を発行する
- `POST /api/calls/[roomId]/end`: caller/calleeどちらでも。現在の`status`と呼び出したuidから理由（`rejected`/`cancelled`/`hangup`）を導出し、`status`を`ended`にする。既に`ended`なら冪等に現状を返す（同時hangupのレース対策）

reject/cancel/hangupを別々のAPIに分けなかったのは、いずれも「通話を終わらせる」という同じ操作であり、理由はサーバー側の状態から一意に決まるため、エンドポイントを増やしてもクライアントの分岐が増えるだけで得られる利益が薄いという判断による。

### Offer/Answer/ICE Candidateは引き続きクライアントの直接RTDB読み書きとする

`docs/adrs/202609262054-call-signaling-via-backend-api.md`の方針を維持する。API経由にするのは「グループ所属チェック」「busy判定」「状態遷移」などサーバーの意思決定を伴う操作のみとし、業務判断を伴わない高頻度なOffer/Answer/ICEの生データ交換は、宣言的なセキュリティルールで境界を表現できる直接書き込みのままにする。

この直接書き込みを安全にするため、`database.rules.json`（リポジトリルート）で以下を強制する。

- `calls/{roomId}`は`caller`/`callee`本人のみ`.read`可
- `status`・`endedReason`・`endedBy`・`caller`・`callee`・`groupId`・各種タイムスタンプは`.write: false`（API＝Admin SDK経由のみ。Admin SDKはルールをバイパスするため書き込みは可能）
- `offer`はcallerのみ、`answer`はcalleeのみ、`iceCandidates/caller`はcallerのみ、`iceCandidates/callee`はcalleeのみ`.write`可

### Firebase Admin SDKの認証情報はファイル配置、CLI設定ファイルはgitignore対象にする

サービスアカウントの秘密鍵は環境変数に埋め込まず、`signaling/secrets/firebase-service-account.json`という固定パスに配置する方式にした（`cert()`はファイルパスを直接受け取れるため）。`docker-compose.yml`の`signaling`サービスは`./signaling:/app`をボリュームマウント済みのため、追加のマウント設定なしにコンテナ内でも同じパスで参照できる。

`database.rules.json`のデプロイに使う`signaling/firebase.json`と、リポジトリルートの`.firebaserc`は、Firebase CLI（`firebase init`）で生成される個人環境向けの設定ファイルとして扱い、`flutter/firebase.json`（FlutterFire CLI生成物）と同様に`.gitignore`対象とする。`database.rules.json`自体は手書きの設定であり生成物ではないため、通常通りコミットする。

## 理由

- ステータスを`calling`/`active`/`ended`の3値に絞ることで、クライアント側の状態管理（画面遷移の分岐）がシンプルになる
- `end`エンドポイントへの統合により、APIの本数を必要最小限（3本）に抑えられる
- Offer/Answer/ICEを直接RTDB書き込みのままにすることで、高頻度なシグナリングデータのためにAPIサーバーを経由させるレイテンシ・実装コストを避けられる。セキュリティ境界はRealtime Databaseのルールで宣言的に表現できる範囲に収まっている
- サービスアカウントをファイル配置にすることで、PEM形式の秘密鍵をdocker-compose/.envに文字列として通す際の改行エスケープ事故を避けられる

## 影響・トレードオフ

- `database.rules.json`は`firebase deploy --only database`で明示的にデプロイする必要がある。デプロイし忘れるとデフォルトの拒否ルールのままになり、クライアントの直接読み書きがすべて失敗する
- `signaling/firebase.json`と`.firebaserc`が別ディレクトリ（`signaling/`とリポジトリルート）に分かれているため、`firebase` CLIが`.firebaserc`を自動認識できない可能性がある。`firebase deploy`実行時に`--project voip-env`を明示するか、都度プロジェクトを選択する運用になる
- クライアントがクラッシュ・回線断した場合の`busy`残留や着信タイムアウトのサーバー側強制は未実装（Flutterクライアント実装時に別途検討する）
- `calls/{roomId}`は通話終了後も削除しないため、長期運用ではレコードが増え続ける。アーカイブ・削除方針は将来検討
