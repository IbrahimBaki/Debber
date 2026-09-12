import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

/**
 * Page/action-level guard: confirms a signed-in identity and active super_admin status before
 * rendering any protected screen or running any mutation. This is defense-in-depth, not the
 * authorization boundary itself -- every admin RPC and every privileged Auth Admin server action
 * independently re-checks is_platform_admin() (or the equivalent) on its own, so a bug here can
 * never be the only thing standing between an unprivileged caller and admin data.
 */
export async function requireAdmin() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();

  if (claimsError || !claims?.claims?.sub) {
    redirect("/login");
  }

  const { data: isAdmin, error: adminError } = await supabase.rpc("is_platform_admin");

  if (adminError || !isAdmin) {
    await supabase.auth.signOut();
    redirect("/login?denied=1");
  }

  return { supabase, userId: claims.claims.sub as string };
}
