import { adminAuth } from "@/lib/firebase-admin";
import { ApiError } from "@/lib/api-error";

export async function requireUid(request: Request): Promise<string> {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    throw new ApiError(401, "UNAUTHENTICATED", "Authorization: Bearer <idToken> is required");
  }

  try {
    const decoded = await adminAuth.verifyIdToken(match[1]);
    return decoded.uid;
  } catch {
    throw new ApiError(401, "UNAUTHENTICATED", "idToken is invalid or expired");
  }
}
