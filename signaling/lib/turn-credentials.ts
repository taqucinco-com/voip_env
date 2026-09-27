import { createHmac } from "crypto";

const CREDENTIAL_TTL_SECONDS = 3600;

export type IceServer = {
  urls: string;
  username?: string;
  credential?: string;
};

// coturnのREST API認証（static-auth-secret）方式。
// username は "有効期限(unix time):任意ラベル"、credential は
// HMAC-SHA1(secret, username) をbase64化したもの。
// https://github.com/coturn/coturn/blob/master/docs/turn_client_third_party_authorisation.pdf
export function buildIceServers(uid: string): IceServer[] {
  const secret = process.env.TURN_SECRET;
  const host = process.env.TURN_HOST;
  if (!secret || !host) {
    throw new Error("TURN_SECRET or TURN_HOST is not set");
  }

  const expiresAt = Math.floor(Date.now() / 1000) + CREDENTIAL_TTL_SECONDS;
  const username = `${expiresAt}:${uid}`;
  const credential = createHmac("sha1", secret).update(username).digest("base64");

  return [
    { urls: `stun:${host}` },
    { urls: `turn:${host}?transport=udp`, username, credential },
  ];
}
