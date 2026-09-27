import { NextResponse } from "next/server";
import { requireUid } from "@/lib/auth";
import { acceptCall } from "@/lib/calls";
import { apiErrorResponse } from "@/lib/api-error";

export async function POST(
  request: Request,
  ctx: RouteContext<"/api/calls/[roomId]/accept">,
) {
  try {
    const uid = await requireUid(request);
    const { roomId } = await ctx.params;

    const result = await acceptCall(uid, roomId);
    return NextResponse.json(result, { status: 200 });
  } catch (error) {
    return apiErrorResponse(error);
  }
}
