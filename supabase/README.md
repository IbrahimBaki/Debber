# Supabase directory

This repository uses Supabase CLI migrations as a mandatory development workflow.

## First machine setup

The generated blueprint intentionally does not pin a hand-written `config.toml`, because the Supabase CLI owns that file format. On the first real project bootstrap, run:

```bash
supabase init
```

Review the generated `supabase/config.toml`, configure local Auth URLs/providers as needed, and commit it. Do not put secrets directly in `config.toml`; reference environment variables where required.

Then run:

```bash
supabase start
supabase db reset
supabase test db
```

Do not link or push to production until these commands pass cleanly.
