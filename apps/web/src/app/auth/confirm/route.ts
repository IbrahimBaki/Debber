import { type NextRequest, NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

const supportedTypes = new Set(["email", "recovery"]);

// NEXT_PUBLIC_SITE_URL is an optional override; request.nextUrl already carries the exact origin
// this request actually arrived on, so it is always available here without depending on that
// env var at all (unlike the Server Action equivalent in ../actions.ts, a Route Handler always
// has the request object, making this the more reliable source of truth).
function authUrl(request: NextRequest, path: string) {
  const origin = process.env.NEXT_PUBLIC_SITE_URL || request.nextUrl.origin;
  return new URL(path, origin);
}

export async function GET(request: NextRequest) {
  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const type = request.nextUrl.searchParams.get("type");
  // A recovery link that fails (already used/expired) must not be explained with confirmation
  // wording -- the two failures mean different things to the user (see login/page.tsx).
  const failureUrl = authUrl(request, `/login?auth_error=${type === "recovery" ? "recovery" : "confirmation"}`);

  if (!tokenHash || !type || !supportedTypes.has(type)) {
    return NextResponse.redirect(failureUrl);
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({
    token_hash: tokenHash,
    type: type as "email" | "recovery",
  });

  if (error) {
    return NextResponse.redirect(failureUrl);
  }

  const destination = type === "recovery" ? "/reset-password" : "/app";
  return NextResponse.redirect(authUrl(request, destination));
}
