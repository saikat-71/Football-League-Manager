# Touchline — Football League Manager

A mobile-responsive football league management web app. The supplied Season 7 dataset is retained (`data/league.json` and `data/seed.js`), including 372 player records, 9 legacy clubs and prize records. The app now uses Supabase Auth + PostgreSQL rather than treating browser `localStorage` as a shared database.

## Important: one-time backend setup

GitHub Pages serves static files only. It cannot securely run authentication, enforce permissions or coordinate bids by itself. This project therefore needs a Supabase project (the free tier is suitable for a prototype; check current quotas before production use).

1. Create a Supabase project.
2. In **SQL Editor**, run the complete `supabase/schema.sql` file.
3. In **Project Settings → API**, copy the Project URL and the `anon` / publishable public key.
4. Edit `data/config.js` and replace `YOUR-PROJECT` and `YOUR_SUPABASE_ANON_KEY` with those values. **Never put the service-role key in browser code.**
5. Enable email/password sign-in in **Authentication → Providers**. Set Site URL and allowed redirect URLs to your deployed GitHub Pages URL and your local development URL if needed.
6. Publish the whole folder to GitHub Pages from the repository root.
7. Create your first account in the website. In Supabase SQL Editor, promote it to the initial Admin by replacing the username below. This is a one-time secure bootstrap step; after that, routine account approvals, role changes, team/auction/fixture and other league operations are managed from the website Admin Dashboard:

   ```sql
   update public.profiles
   set role = 'admin', status = 'active'
   where username = 'YOUR_USERNAME';
   ```

8. Sign out and sign back in. New accounts are `pending` until an Admin approves them in **User Accounts**. After approval, a User can create one active team immediately; there is no separate team-approval step. New Users register themselves on the website; the Admin does not send invitation emails in this no-Edge-Function build.
9. As Admin, open **Settings & Audit → Import players from Excel** once. The importer skips player records whose `legacy_id` already exists. Review legacy ownership and budgets before treating the imported data as official.

## What is implemented in this update

- Supabase email/password authentication, pending account approval, Admin/User role separation and website-based account status/role management. New Users register themselves from the website and Admin approves them in User Accounts. Account archive preserves competition history, cancels active bids/transfers, releases players and disables access in this app; physical deletion of the Supabase Auth identity is not included because that requires a privileged server-side Auth API.
- PostgreSQL schema with Row Level Security (RLS); browser code uses only the public anon key.
- Public read-only pages for player records, teams/squads and fixtures/standings.
- One team per account enforced by a unique `owner_id`; an approved User can create one active team immediately, while Admin can later deactivate/reactivate it, manage formation/budget and delete it with history retention. Deleted team rows are retained for historical fixtures and transactions; players become free agents.
- Player database, detailed football positions, Admin player create/edit/delete, User player proposals, Admin verification and final base price.
- Multiple simultaneous auction records, Admin start/pause/resume/cancel, fixed countdowns, minimum increment, atomic bid placement, budget reservation across active bids and automatic resolution when an authenticated app session polls for expired auctions.
- Auction winner finalization and purchase ledger update in a database transaction; no second deduction at settlement.
- Transfer request creation through a checked database function, buyer/seller acceptance, player lock and atomic ownership/ledger settlement.
- Admin fixture creation, result entry/correction with audit trail, automatically calculated points table (3/1/0; GD; goals scored).
- In-app notifications, budget adjustment ledger and audit history.
- Responsive desktop, tablet and mobile layout.

## Auction timing / automatic expiry

Countdowns are fixed and are not extended by new bids. The app calls `resolve_expired_auctions()` while an authenticated session is open, so an expired auction is finalized when an active client polls. For unattended, exact background finalization, enable Supabase `pg_cron` (if available on your project) and schedule the database function every minute. Example after enabling the extension:

```sql
select cron.schedule(
  'touchline-resolve-expired-auctions',
  '* * * * *',
  $$ select public.resolve_expired_auctions(); $$
);
```

## Security and configuration notes

- RLS is the security boundary. UI role checks are only presentation; server-side policies/RPCs validate important operations.
- Do not share or commit a Supabase service-role secret. `data/config.js` must contain only the project URL and public anon/publishable key.
- Password recovery is intentionally Admin-assisted in this version; no public self-service reset flow is wired.
- Admin promotion is performed once from SQL Editor. Keep at least one active Admin account.
- The historical workbook's balances are provisional. The original data notes show that legacy balance-owner labels do not fully match current Season 7 club names; reconcile them before official use.
- Money values are stored as whole/decimal units and shown using the configured currency label (default `TK M`).

## Validation performed in this workspace

- JavaScript syntax checked with Node.js.
- `data/league.json` parsed as valid JSON.
- ZIP contents and source dataset structure inspected.

## Not verified here

- A live Supabase project is not connected because no project URL/key were provided.
- The SQL schema has not been executed against a real Supabase database in this workspace.
- Live multi-user bidding, email confirmation, RLS policies, background cron, GitHub Pages deployment and real device/browser behaviour therefore remain **unverified** until you configure and test your own Supabase project.

## Project files

- `index.html` — app entry point
- `styles.css` — responsive interface
- `app.js` — frontend workflows
- `data/config.js` — public Supabase configuration placeholders
- `data/league.json` — original dataset and import source
- `data/seed.js` — retained legacy first-load dataset
- `supabase/schema.sql` — tables, RLS, checked RPC functions and audit/transaction schema


## Excel player import and email redirect
- Email confirmation redirects to `https://saikat-71.github.io/Football-League-Manager/` and then shows the login screen. In Supabase Auth URL Configuration, set that as Site URL and allow `https://saikat-71.github.io/Football-League-Manager/**`.
- Admin can import `.xlsx`, `.xls`, or `.csv` from Settings & Audit. Only player rows are imported; all imported players are free agents with no owner. Teams, clubs, ownership, and budgets are not imported.
- Expected column: `Name` or `Player Name`. Optional: `ID`, `Position`, `Rating`/`Overall`, `Age`, `Nationality`, `Base Price`/`Price`.


## Public dashboard, install icon, and bundled player list

The app now opens on the public dashboard before authentication. Sign-in and registration are available from the sidebar/top bar. A `manifest.webmanifest` and Apple touch icon reference are included so the Touchline logo can appear when the site is added to a phone's Home Screen.

The Excel workbook's **Auction Players with Positions** worksheet was normalized into `data/player-list.json` (184 unique players). After configuring Supabase and promoting your first account to Admin, choose **Import bundled 184-player list** from the dashboard or Settings & Audit. This imports only player records as free agents with `owner_team_id = null`; it creates no teams and imports no ownership or budgets. Existing matching IDs/names are skipped. The source sheet did not provide dependable age, nationality, or base-price data, so those fields are blank/1 respectively and can be edited later. The import must be initiated by an authenticated Admin; it is not silently run against the database.
