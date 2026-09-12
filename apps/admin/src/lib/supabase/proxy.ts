import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import type { Database } from "../../../../../packages/database/src/database.types";

import { hasSupabasePublicConfig } from "./config";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  if (!hasSupabasePublicConfig()) {
    return response;
  }

  const supabase = createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // getClaims validates a cookie-backed identity when one exists. Do not use
  // getSession() as an authorization check in server code.
  await supabase.auth.getClaims();

  return response;
}
