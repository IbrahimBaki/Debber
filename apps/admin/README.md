# Dabber Super Admin

Separate Next.js application. Privileged operations are server-only and require both normal operator authentication and an active `platform_admins.role = super_admin` authorization check before use of `SUPABASE_SECRET_KEY`.

Run locally with:

```bash
npm run dev --workspace=admin
```
