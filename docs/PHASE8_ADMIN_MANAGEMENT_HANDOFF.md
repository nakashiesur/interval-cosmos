# INTERVAL COSMOS v2.0.5 — Phase 8 Admin Management Handoff

## Repository implementation status

The Phase 8 admin mutation layer is implemented in `v2.0.5-dev`.

### Browser UI

`phase8-admin-player-management-v205.js/css`

From a student detail screen, an admin can open `MANAGE STUDENT` and:
- edit player name / course / avatar,
- suspend or restore the account,
- unpublish public ranking records without deleting learning history,
- delete ranking BEST cache with typed `RANKING` confirmation,
- request complete account deletion with typed `DELETE` confirmation.

### Database RPCs

`sql/admin-player-management-v2.0.5.sql`

Browser-callable mutations all enforce `public.is_current_admin()`.

The final application-row deletion is not callable by `authenticated`; it requires the `service_role` JWT and is intended only for the server-side Edge Function.

### Complete deletion

`supabase/functions/admin-delete-player/index.ts`

The Edge Function:
1. receives the human admin's bearer token,
2. verifies `is_current_admin()` with the normal user client,
3. refuses self-deletion,
4. uses the service role only inside the Edge Function,
5. deletes all linked Supabase Auth users,
6. invokes the service-role-only application-row deletion RPC so database cascades remove the player's game data.

No service-role secret is present in browser JavaScript.

## Test-project deployment order

For the test Supabase project:
1. Apply the current full SQL bundle (or at minimum the new `sql/admin-player-management-v2.0.5.sql` after all earlier migrations).
2. Deploy Edge Function `admin-delete-player`.
3. Open the newest `v2.0.5-dev` browser build as an admin.
4. Open ADMIN DASHBOARD → student detail → MANAGE STUDENT.
5. Verify a non-destructive profile edit first.
6. Verify suspend / restore.
7. Verify ranking unpublish on a disposable ranking record.
8. Verify a non-admin cannot use the admin RPCs/UI.
9. Create a disposable student account, then verify complete deletion and confirm its Auth user + application data are gone.

Do not test complete deletion against a real student account.

## Release state

Repository implementation: **IMPLEMENTED**.
Runtime/Supabase verification: **PENDING**.

Issue #10 stays open until the test-project checks above pass.
