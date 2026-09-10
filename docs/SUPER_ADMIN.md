# Dabber Super Admin Architecture

## 1. Product requirement

The Super Admin console is a separate application and deployment. The household app does not reveal admin controls based on a conditional role check.

Recommended domains:

```text
app.dabber.example    → Household PWA
admin.dabber.example  → Platform Super Admin
```

## 2. Super Admin capabilities

### MVP admin read access

- All Supabase Auth users.
- User auth metadata required for support.
- All profiles.
- All households and memberships.
- Household budget periods.
- Income data.
- Sections and recurring items.
- Transactions and audit events.

### Privileged actions

Add only with explicit confirmation and audit logging:

- disable/ban an account;
- revoke sessions where supported by the chosen flow;
- update account/support state;
- remove a member from a household when resolving a support issue;
- archive a household;
- corrective financial/admin actions with a required reason.

Avoid editing financial history casually. Prefer support-safe operations and audit every mutation.

## 3. Authentication and authorization

The admin app uses ordinary Supabase Auth for operator login, then verifies platform authorization separately.

Source of truth:

```text
platform_admins
  user_id
  role
  is_active
```

Do not rely on email matching. Do not use user-editable `user_metadata` for authorization.

## 4. Secret Key usage

The Supabase Secret Key bypasses RLS and has broad data access. It must:

- exist only in the admin Vercel project's server environment;
- never be returned to browser code;
- never be stored in Git;
- never be used by `apps/web`;
- be instantiated in a dedicated server-only module;
- not be combined with an end-user access token.

## 5. Recommended request flow

```text
GET /admin/users
     │
     ├─ validate normal user session
     ├─ query own platform_admins marker under RLS
     ├─ require active role = super_admin
     ├─ instantiate server-only privileged client
     ├─ call auth.admin.listUsers() / database queries
     └─ return only the fields the Admin UI needs
```

Even though the operator has full platform access, return minimum necessary payloads to each browser screen.

## 6. Admin dashboard information architecture

```text
Dashboard
Users
Households
Budgets
Transactions
Recurring Items
Audit Logs
System
```

User inspector:

```text
Profile
Auth info
Last sign-in
Memberships
Owned households
Recent activity
Admin actions
```

Household inspector:

```text
Owner
Members
Settings
Periods
Income
Sections
Recurring items
Transactions
Household audit log
```

## 7. Audit requirements

Every privileged mutation writes `admin_audit_logs` with:

- admin user;
- action;
- target type/id;
- reason for high-risk actions;
- metadata that does not contain secrets;
- timestamp.

Admin audit logs are not available to normal authenticated clients.

## 8. Defense-in-depth

Before production:

- protect `admin.*` with its own deployment/environment variables;
- consider MFA for platform admins;
- add rate limiting to sensitive admin actions;
- require re-authentication for destructive account operations if appropriate;
- use protected production deployments;
- keep Secret Key rotation documented;
- add alerting for repeated admin authorization failures.
