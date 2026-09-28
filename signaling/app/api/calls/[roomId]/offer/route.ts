import { NextResponse } from "next/server";
import { requireUid } from "@/lib/auth";
import { submitOffer } from "@/lib/calls";
import { ApiError, apiErrorResponse } from "@/lib/api-error";

export async function POST(
  request: Request,
  ctx: RouteContext<"/api/calls/[roomId]/offer">,
) {
  try {
    const uid = await requireUid(request);
    const { roomId } = await ctx.params;

    const body = await request.json().catch(() => null);
    const sdp = body?.sdp;
    if (typeof sdp !== "string") {
      throw new ApiError(400, "INVALID_REQUEST", "sdp is a required string");
    }

    await submitOffer(uid, roomId, sdp);
    return NextResponse.json({}, { status: 200 });
  } catch (error) {
    return apiErrorResponse(error);
  }
}
