import { createBrowserClient } from "@supabase/ssr";

import type { Database } from "../../../../../packages/database/src/database.types";

import { getSupabasePublicConfig } from "./config";

export function createClient() {
  const { url, publishableKey } = getSupabasePublicConfig();

  return createBrowserClient<Database>(url, publishableKey);
}
