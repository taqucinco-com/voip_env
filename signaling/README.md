This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

管理画面を想定。

```sh
ipconfig getifaddr en0
```
でLAN内Ipアドレスを取得できる。

## Signaling API

通話シグナリング用のバックエンドAPI。データ設計の詳細は[ルートREADME](../README.md#realtime-database)、経緯は`docs/adrs/`を参照。

### 環境変数

`.env`（リポジトリルート）に設定し、`docker-compose.yml`経由でこのコンテナに渡す。

- `FIREBASE_DATABASE_URL`: 例 `https://voip-env-default-rtdb.firebaseio.com`
- `TURN_SECRET`: coturnと共有する時限認証シークレット（`coturn/README.md`参照）
- `TURN_HOST`: coturnのホスト:ポート。例 `192.168.x.x:3478`（上記の`ipconfig getifaddr en0`で自分のLAN内IPを確認する）

### サービスアカウント（Firebase Admin SDK）

1. Firebase Console → プロジェクトの設定 → サービスアカウント → 「新しい秘密鍵の生成」でJSONをダウンロード
2. `signaling/secrets/firebase-service-account.json`に配置する（`.gitignore`対象。コミットしない）

### 起動方法

```sh
# Next.js単体をローカルで動かす場合
npm install
npm run dev

# Docker Compose（coturnも含めて動かす場合。ルートディレクトリで実行）
cd ..
docker compose up -d signaling coturn
```

### APIエンドポイント

いずれも`Authorization: Bearer <Firebase IDトークン>`ヘッダーが必要。

| メソッド | パス                        | 用途                                                             |
| -------- | --------------------------- | ---------------------------------------------------------------- |
| POST     | `/api/calls/start`          | 発信。body: `{ "calleeUid": string, "groupId": string }`          |
| POST     | `/api/calls/[roomId]/accept`| 応答（`calling` → `active`）                                     |
| POST     | `/api/calls/[roomId]/end`   | 終了（拒否/発信取消/通話終了を1本に統合。理由はサーバー側で導出） |

Offer/Answer/ICE Candidateの交換はAPIを経由せず、クライアントが`calls/{roomId}`配下に直接読み書きする。

### Realtime Databaseルールのデプロイ

`database.rules.json`（リポジトリルート）を反映するには、`firebase.json`があるこの`signaling/`ディレクトリで`firebase` CLIを使う。

```sh
# 初回のみ
firebase login
firebase init database
# → 既存プロジェクト voip-env を選択
# → ルールファイルの参照先は ../database.rules.json を指定

# データーベースインスタンスの存在確認
firebase database:instances:list --project=voip-env

# データを確認
firebase database:get / --project=voip-env --pretty

# ルールをデプロイ
firebase deploy --only database --project=voip-env

# デプロイしたルールを確認
firebase database:get /.settings/rules --project=voip-env
```

`.firebaserc`はリポジトリルートに置く運用のため、`firebase init`実行時にこのディレクトリに生成された場合はリポジトリルートへ移動するか、`firebase deploy --project voip-env`のようにプロジェクトを明示する。
