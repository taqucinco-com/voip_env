# Coturn (STUN/TURNサーバー)

## 1. 起動方法

リポジトリルートの `.env` に `TURN_SECRET` が設定されていることを確認してから起動する。

```bash
# 初回のみ: .env.example を参考に .env を作成
cp .env.example .env

# coturn コンテナを起動
docker compose up -d coturn

# ログ確認
docker logs coturn
```

停止する場合は以下。

```bash
docker compose stop coturn
```

## 2. STUNの起動確認方法

coturnイメージに含まれる `turnutils_stunclient` で、自分自身のreflexive address（外部から見えるIP:ポート）が取得できるか確認する。

```bash
docker exec coturn turnutils_stunclient 127.0.0.1
```

以下のように `UDP reflexive addr` が返ってくればSTUNは正常に動作している。

```
IPv4. UDP reflexive addr: 127.0.0.1:xxxxx
```

## 3. TURNの起動確認方法

TURNはリレー通信のため、REST API認証（`static-auth-secret` によるHMAC-SHA1署名）で発行した時限トークンが必要になる。以下はローカル検証用にその場でトークンを生成してAllocateを試すコマンド。

`-e`（ピアアドレス）には、coturnがデフォルトで中継を拒否するループバック（`127.0.0.1`）ではなく、自分のLAN内IPアドレスを指定する。

```bash
# 自分のLAN内IPアドレスを確認
ipconfig getifaddr en0

TURN_SECRET=$(grep TURN_SECRET .env | cut -d= -f2)
TURN_USER="$(($(date +%s)+3600)):testuser"
TURN_CRED=$(printf '%s' "$TURN_USER" | openssl dgst -sha1 -hmac "$TURN_SECRET" -binary | base64)

# <LANのIPアドレス> は ipconfig getifaddr en0 の結果に置き換える
docker exec coturn turnutils_uclient -t -u "$TURN_USER" -w "$TURN_CRED" -e <LANのIPアドレス> 127.0.0.1
```

- `Total connect time is 1` が出て `tot_send_msgs` が増えていけば、Allocate（認証）〜CreatePermission/ChannelBind〜中継まですべて成功している。
- `<LANのIPアドレス>` 側で実際に応答するアプリは動いていないため、`tot_recv_msgs=0` のままなのは正常（中継経路自体は通っている）。
- `channel bind: error 403` が出た場合は、ピアアドレスにループバック（`127.0.0.1`）やマルチキャストアドレスを指定してしまっている可能性が高い。coturnはデフォルトでこれらへの中継を拒否するため、実在するLAN内IPアドレスなどに変更する。
- `Cannot complete Allocation` が出た場合は、`TURN_USER` / `TURN_CRED` が空になっている、または `TURN_SECRET` が `.env` の値と一致していないなど、認証情報の生成に問題がある。
