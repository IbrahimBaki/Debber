import { createClient as createSupabaseClient } from "@supabase/supabase-js";

import type { Database } from "../../../../../packages/database/src/database.types";

// Server-only. This module instantiates a client with the Supabase Secret Key, which bypasses
// RLS and can mutate any Auth user. It must never be imported from a Client Component, never
// receive an end-user access token, and never be used for ordinary database reads -- ordinary
// reads go through session-authenticated RPCs (see ./server.ts) that independently re-verify
// is_platform_admin(). Exactly five named operations are exposed; there is no general escape
// hatch to the underlying admin client.
if (typeof window !== "undefined") {
  throw new Error("apps/admin/lib/supabase/admin-auth.ts must never run in the browser.");
}

function getPrivilegedClient() {
  const url = process.env.SUPABASE_URL;
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!url || !secretKey) {
    throw new Error("Supabase privileged server environment configuration is missing.");
  }

  return createSupabaseClient<Database>(url, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export type AuthUserSummary = {
  id: string;
  email: string | null;
};

function toSummary(user: { id: string; email?: string | null }): AuthUserSummary {
  return { id: user.id, email: user.email ?? null };
}

/**
 * Creates a new Auth user. `activateImmediately` maps directly to email_confirm -- there is no
 * separate application-level activation flag; native GoTrue confirmation state is the sole
 * source of truth for whether the account can sign in yet.
 */
export async function createAuthUser(params: {
  email: string;
  password: string;
  activateImmediately: boolean;
}): Promise<AuthUserSummary> {
  const client = getPrivilegedClient();
  const { data, error } = await client.auth.admin.createUser({
    email: params.email,
    password: params.password,
    email_confirm: params.activateImmediately,
  });

  if (error || !data.user) {
    throw new Error(error?.message ?? "auth_create_user_failed");
  }

  return toSummary(data.user);
}

/** Marks a needs-activation account as confirmed, allowing it to sign in. */
export async function activateAuthUser(userId: string): Promise<void> {
  const client = getPrivilegedClient();
  const { error } = await client.auth.admin.updateUserById(userId, { email_confirm: true });

  if (error) {
    throw new Error(error.message);
  }
}

/**
 * Disables an account via GoTrue's native ban mechanism (a far-future ban_duration). Sign-in
 * attempts are rejected server-side; no separate application-level "disabled" flag exists.
 */
export async function disableAuthUser(userId: string): Promise<void> {
  const client = getPrivilegedClient();
  const { error } = await client.auth.admin.updateUserById(userId, { ban_duration: "876000h" });

  if (error) {
    throw new Error(error.message);
  }
}

/** Re-enables a previously disabled account by lifting the ban. */
export async function enableAuthUser(userId: string): Promise<void> {
  const client = getPrivilegedClient();
  const { error } = await client.auth.admin.updateUserById(userId, { ban_duration: "none" });

  if (error) {
    throw new Error(error.message);
  }
}

/**
 * Sets a new password for an account. Verified against the local Supabase Auth stack: this also
 * immediately invalidates any session issued before the change (GoTrue rejects the old access
 * token with `session_not_found`) -- there is no separate session-revocation step to perform.
 */
export async function setAuthUserPassword(userId: string, newPassword: string): Promise<void> {
  const client = getPrivilegedClient();
  const { error } = await client.auth.admin.updateUserById(userId, { password: newPassword });

  if (error) {
    throw new Error(error.message);
  }
}
