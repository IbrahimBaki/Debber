import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import type { Database } from "../../../../../packages/database/src/database.types";

import { getSupabasePublicConfig } from "./config";

// The ordinary, session-authenticated client. Every admin data read/write in this app goes
// through a security-definer RPC that independently re-checks is_platform_admin() -- this client
// is never granted broad raw-table access and never bypasses RLS. See ./admin-auth.ts for the
// separate, narrowly-scoped privileged client used only for the five named Auth Admin API calls.
export async function createClient() {
  const cookieStore = await cookies();
  const { url, publishableKey } = getSupabasePublicConfig();

  return createServerClient<Database>(url, publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Server Components cannot persist cookies. The Next.js Proxy refreshes them.
        }
      },
    },
  });
}
