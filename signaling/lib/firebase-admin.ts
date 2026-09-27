import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getDatabase } from "firebase-admin/database";

// サービスアカウントの秘密鍵ファイルは signaling/secrets/firebase-service-account.json
// に配置する（.gitignore対象、docker-compose上は ./signaling:/app のマウントで
// コンテナ内にもそのまま反映される）。パスは環境変数で上書き可能にしておく。
const serviceAccountPath =
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH ??
  "./secrets/firebase-service-account.json";

// Next.jsの開発サーバーはモジュールを再評価することがあるため、
// 既存appがあればそれを再利用し多重初期化エラーを避ける。
const app: App =
  getApps()[0] ??
  initializeApp({
    credential: cert(serviceAccountPath),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });

export const adminAuth = getAuth(app);
export const adminDb = getDatabase(app);
