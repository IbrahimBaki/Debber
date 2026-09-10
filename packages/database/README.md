# Database Types

Generate after local migrations are applied:

```bash
supabase gen types --lang typescript --local > packages/database/src/database.types.ts
```

Commit generated database types whenever a migration changes the schema consumed by application code.
