import { notFound } from "next/navigation";

import {
  getSupabasePublicConfig,
  hasSupabasePublicConfig,
} from "@/lib/supabase/config";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type CheckResult =
  | { status: "configuration-missing" }
  | { status: "unauthenticated" }
  | { status: "authenticated" }
  | { status: "unreachable" };

async function runCheck(): Promise<CheckResult> {
  if (!hasSupabasePublicConfig()) {
    return { status: "configuration-missing" };
  }

  try {
    const { url } = getSupabasePublicConfig();
    const health = await fetch(`${url}/auth/v1/health`, {
      cache: "no-store",
    });

    if (!health.ok) {
      return { status: "unreachable" };
    }

    const supabase = await createClient();
    const { data, error } = await supabase.auth.getClaims();

    if (error) {
      return { status: "unreachable" };
    }

    return data?.claims
      ? { status: "authenticated" }
      : { status: "unauthenticated" };
  } catch {
    return { status: "unreachable" };
  }
}

export default async function SupabaseCheckPage() {
  // Development-only diagnostic: this must never be reachable in a deployed environment,
  // since it discloses backend reachability/configuration/session state to any visitor.
  if (process.env.NODE_ENV !== "development") {
    notFound();
  }

  const result = await runCheck();

  const content = {
    "configuration-missing": {
      title: "Supabase public configuration is missing",
      detail:
        "Add the local public URL and publishable key to apps/web/.env.local, then restart the development server.",
    },
    unauthenticated: {
      title: "Local Supabase is reachable",
      detail:
        "No authenticated user is present, which is expected before authentication is implemented.",
    },
    authenticated: {
      title: "Local Supabase is reachable",
      detail:
        "An authenticated browser session is present. This diagnostic does not display user or credential data.",
    },
    unreachable: {
      title: "Unable to verify local Supabase",
      detail:
        "Check that the local stack is running and that the public environment values are valid. No credentials are displayed here.",
    },
  }[result.status];

  return (
    <main dir="ltr">
      <p>Development diagnostic</p>
      <h1>{content.title}</h1>
      <p>{content.detail}</p>
      <p>This temporary route is not a product screen and does not query household data.</p>
    </main>
  );
}
