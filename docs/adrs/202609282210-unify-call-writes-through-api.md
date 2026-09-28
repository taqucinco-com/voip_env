# calls/{roomId}への書き込みをOffer/Answer/ICE Candidateも含めてAPI経由に統一する

## ステータス

承認済み（`docs/adrs/202609271801-call-room-schema-and-signaling-endpoints.md`の「Offer/Answer/ICE Candidateは引き続きクライアントの直接RTDB読み書きとする」という決定を覆す）

## コンテキスト

`docs/adrs/202609271801-call-room-schema-and-signaling-endpoints.md`では、`calls/{roomId}`配下の書き込み経路を2種類に使い分けていた。

- `status`・`endedReason`等の管理フィールド: サーバーの意思決定を伴うためAPI（Admin SDK）経由でのみ書き込み可能
- `offer`・`answer`・`iceCandidates`: 業務判断を伴わない高頻度な生データ交換のため、クライアントの直接RTDB書き込みを許可（`database.rules.json`で送信者本人のみ書き込み可、という条件式を個別に用意）

この使い分けにより、同じ`calls/{roomId}`という1つのリソースの中に「書き込みはAPI経由」と「書き込みはクライアント直接」という異なる責務分担が混在し、`database.rules.json`の`.write`条件もフィールドごとに個別の式（`auth.uid === caller`等）を持つ形になっていた。

あらためて設計を見直し、「DBへの書き込みはすべてAPI（サーバー）側の責務、DBの監視・読み取りはすべてクライアント側の責務」という一貫した役割分担に統一する方針とした。

## 決定

`offer`・`answer`・`iceCandidates`への書き込みも、`calls/{roomId}`の他の管理フィールドと同様にAPI経由に変更する。

- `POST /api/calls/[roomId]/offer`: caller本人のみ。`{ sdp }`を受け取り`calls/{roomId}/offer`に書き込む
- `POST /api/calls/[roomId]/answer`: callee本人のみ。`{ sdp }`を受け取り`calls/{roomId}/answer`に書き込む
- `POST /api/calls/[roomId]/ice-candidates`: caller/callee本人のみ。`{ candidate, sdpMid, sdpMLineIndex }`を受け取り、呼び出したuidがcaller/calleeのどちらかをサーバー側で判定した上で`calls/{roomId}/iceCandidates/{caller|callee}`にpushする

送信された値の非同期な反映（相手が送ったOffer/Answer/ICE Candidateを受け取ること）は、引き続きクライアントがRealtime Databaseを監視して読み取る。読み取り専用の直接アクセス（`.read`）は変更しない。

`database.rules.json`は`offer`・`answer`・`iceCandidates`すべてを`.write: false`にし、Admin SDK（API）以外からの書き込みを一律禁止する。

## 理由

- 単一リソース（`calls/{roomId}`）内で書き込み経路がフィールドごとに異なる状態は、ルールの見通しの悪さや、将来フィールドを追加する際にどちらの経路にすべきか毎回判断するコストを増やす
- 書き込みをAPI経由に統一することで、`database.rules.json`の`.write`条件はすべて`false`に単純化できる。送信者が本当にcaller/calleeか等のバリデーションも、セキュリティルールの条件式ではなくサーバーコード（TypeScript、`lib/calls.ts`）に集約できる
- 読み取り（監視）は変わらずクライアントの責務のままとし、相手からの更新をリアルタイムに受け取る部分（RTDBのリスナー）の実装は変更しない

## 影響・トレードオフ

- Offer/ICE Candidateの送信がAPIサーバーを経由するようになるため、直接RTDB書き込みと比べてレイテンシが増える。これは`docs/adrs/202609271801-call-room-schema-and-signaling-endpoints.md`が指摘していた「高頻度なICE候補交換のためにAPIサーバーを経由させるレイテンシ・実装コストを避ける」というメリットを手放す判断である
- ICE Candidateは1通話あたり複数回発生しうるため、API呼び出し回数とsignalingサーバーの負荷が増える
- signalingサーバーに`offer`/`answer`/`ice-candidates`の3エンドポイントが追加される
