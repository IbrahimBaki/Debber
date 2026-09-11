import { type NextRequest, NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

const supportedTypes = new Set(["email", "recovery"]);

function authUrl(path: string) {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL;

  if (!siteUrl) {
    throw new Error("Site URL is not configured.");
  }

  return new URL(path, siteUrl);
}

export async function GET(request: NextRequest) {
  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const type = request.nextUrl.searchParams.get("type");
  // A recovery link that fails (already used/expired) must not be explained with confirmation
  // wording -- the two failures mean different things to the user (see login/page.tsx).
  const failureUrl = authUrl(`/login?auth_error=${type === "recovery" ? "recovery" : "confirmation"}`);

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
  return NextResponse.redirect(authUrl(destination));
}
