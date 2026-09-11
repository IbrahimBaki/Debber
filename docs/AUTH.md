# Dabber Auth v1

Auth v1 uses email and password, mandatory email verification, and password recovery by email. It does not include Google OAuth, other social login, Magic Link login, or email OTP login. Authentication establishes an end-user session; household access remains separately enforced through server checks and PostgreSQL RLS.

## Local development

`supabase/config.toml` enables email confirmations and points its local Site URL to `http://localhost:3000`. The confirmation and recovery templates are version-controlled in `supabase/templates/` and use `token_hash` links to the Web server route `/auth/confirm`.

Run `npx supabase status` to find the local Mailpit URL. In the approved local stack it is available at `http://127.0.0.1:54324`. Use Mailpit only for local testing; do not commit captured messages, links, accounts, tokens, or credentials.

## Flow

1. Signup sends a confirmation message and directs the user to `/check-email`.
2. The confirmation template links to `/auth/confirm?token_hash=…&type=email`.
3. The server verifies the token with `verifyOtp`, writes the SSR cookie session, and redirects to the temporary `/auth/session` route.
4. Password recovery follows the same server verification route with `type=recovery`, then redirects to `/reset-password`.

The temporary authenticated route exists only until a future owner-approved onboarding-routing phase. It does not create or select a household.

## Hosted Supabase later

Before deploying, mirror the confirmation and recovery subjects/templates in the hosted Supabase project and configure its production Site URL and redirect allow list. Production SMTP/provider selection remains an owner decision; no provider is selected by this document.
