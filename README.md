# Touchline --- Football League Manager

A responsive football league management web application for organizing
player records, teams, auctions, transfers, fixtures, standings, and
account access. The frontend is a static website designed for GitHub
Pages, with Supabase providing authentication and the shared PostgreSQL
database.

> **Important:** The website cannot connect to your own Supabase project
> until you configure `data/config.js` and run the SQL schema. A
> successful local syntax check does not prove that live authentication,
> database policies, email delivery, or deployment are working.

## Contents

-   [Features](#features)
-   [Technology stack](#technology-stack)
-   [Project structure](#project-structure)
-   [Requirements](#requirements)
-   [Setup Supabase](#1-create-and-configure-supabase)
-   [Configure the website](#2-configure-the-frontend)
-   [Deploy to GitHub Pages](#3-deploy-to-github-pages)
-   [Create the first Admin](#4-create-the-first-admin)
-   [Import the player list](#5-import-the-player-list)
-   [Account and email confirmation](#account-and-email-confirmation)
-   [Mobile Home Screen icon](#mobile-home-screen-installation)
-   [Profile image and mobile logout](#profile-image-and-mobile-logout)
-   [Testing checklist](#testing-checklist)
-   [Security notes](#security-notes)
-   [Troubleshooting](#troubleshooting)

## Features

-   Public dashboard opens before sign-in; visitors can browse public
    league information.
-   Sign-in and registration are available from the navigation.
-   Supabase email/password authentication and Admin/User role
    separation.
-   New accounts can remain pending until an Admin approves them.
-   Player database with positions, status, ratings and Admin
    management.
-   Import the bundled list of **184 unique players**, or import a
    compatible Excel/CSV file.
-   Player-only import: imported players are free agents, with no team
    ownership assigned.
-   Team and squad management, auctions, bids, transfers, fixtures,
    results and standings supported by the database schema.
-   Settings, budget adjustments, audit history and account management
    for Admins.
-   Responsive desktop, tablet and mobile layout.
-   Touchline branding, browser favicon, web app manifest and mobile
    Home Screen icon support.
-   Profile image upload from My Profile (JPG, PNG or WebP, up to 5 MB).
    The image is resized and stored in that browser's local storage; it
    does **not** automatically sync to other devices.
-   A sign-out option is available in the mobile navigation for
    signed-in users.

## Technology stack

-   HTML5, CSS3 and vanilla JavaScript
-   Supabase Auth
-   Supabase PostgreSQL, Row Level Security (RLS), and database
    functions
-   SheetJS browser library for Excel import
-   Web App Manifest and Apple touch icon metadata
-   GitHub Pages (static hosting)

## Project structure

``` text
Football-League-Manager-main/
├── index.html                 # Main HTML entry point
├── app.js                     # Frontend application and interactions
├── styles.css                 # Responsive styling
├── manifest.webmanifest       # Installable web app metadata
├── assets/
│   └── touchline-logo.png     # Touchline logo / app icon source
├── data/
│   ├── config.js              # Supabase URL and public anon key
│   ├── player-list.json       # Bundled list of 184 unique players
│   ├── league.json            # Retained legacy league dataset
│   └── seed.js                # Retained legacy seed data
└── supabase/
    ├── schema.sql             # Database schema, RLS and functions
    └── migrations/
        └── 20261030_admin_dashboard_without_edge_function.sql
```

## Requirements

-   A GitHub account and a repository for the site
-   A Supabase project
-   A modern browser
-   The project files at the repository root for the standard GitHub
    Pages project URL

## 1. Create and configure Supabase

1.  Create a project in the Supabase dashboard.
2.  Open **SQL Editor**.
3.  Run the complete `supabase/schema.sql` script from this repository.
4.  Open **Project Settings → API** and copy the Project URL and the
    **anon/publishable public key**.
5.  In **Authentication → Providers**, enable Email/password sign-in.
6.  In **Authentication → URL Configuration**, configure the deployed
    site URL and redirect allow list as described below.

Do not put a Supabase `service_role` key in frontend files. It is a
privileged secret and must never be committed to GitHub.

## 2. Configure the frontend

Edit `data/config.js`:

``` js
window.APP_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseAnonKey: "YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY",
  appName: "Touchline Football League Manager",
  siteUrl: "https://YOUR-GITHUB-USERNAME.github.io/YOUR-REPOSITORY/",
  currencyLabel: "TK M"
};
```

Replace the example values with your own Supabase URL, public key and
deployed website URL. Keep the trailing slash on the site URL.

For this project, the intended GitHub Pages URL is:

`https://saikat-71.github.io/Football-League-Manager/`

Use that exact URL in `data/config.js` if you are deploying to that
repository.

## 3. Deploy to GitHub Pages

1.  Upload the project contents to the root of your GitHub repository.
    The `index.html` file should be at the published root, not buried in
    an extra folder.
2.  Open the repository's **Settings → Pages**.
3.  Choose the `main` branch and `/ (root)` as the publishing source, if
    that matches your repository structure.
4.  Save and wait for the deployment to finish.
5.  Open the published URL and verify the public dashboard loads.

If you use a different branch or build process, configure Pages to match
that setup.

## 4. Create the first Admin

Create an account through the website first. Then open Supabase **SQL
Editor** and promote that account using its exact username:

``` sql
update public.profiles
set role = 'admin',
    status = 'active'
where username = 'YOUR_USERNAME';
```

Replace `YOUR_USERNAME` with the username you registered. Run this
one-time bootstrap only for the account that should be the initial
Admin. Then sign out and sign back in.

New accounts may remain pending until an Admin approves them from the
website's account-management screen. Keep at least one active Admin
account.

## 5. Import the player list

After signing in as an Admin:

1.  Open the dashboard or **Settings & Audit**.
2.  Select **Import bundled 184-player list** to import the supplied
    list, or select **Import Excel/CSV** to choose your own spreadsheet.
3.  Review the import result and inspect the player list.

### Player-only import rules

-   Players are imported as free agents.
-   `owner_team_id` is left empty (`null`).
-   The importer does not create teams or clubs.
-   Team ownership and team budgets are not imported.
-   Existing matching player IDs/names are skipped to reduce duplicates.

For a custom Excel workbook, the importer expects a column named `Name`
or `Player Name`. Optional columns include `ID`, `Position`, `Rating` or
`Overall`, `Age`, `Nationality`, and `Base Price` or `Price`. The
importer reads the first worksheet. Export the workbook to CSV if your
browser or spreadsheet format causes problems.

The bundled list has 184 unique player records. Some fields, such as
age, nationality or base price, may be blank or use a default when the
source workbook did not provide reliable values. Review those fields
before using them for an official auction.

**Importing is an Admin action and writes to the connected Supabase
database.** It is not performed merely by opening the website.

## Account and email confirmation

In Supabase **Authentication → URL Configuration**, set:

-   **Site URL:** `https://saikat-71.github.io/Football-League-Manager/`
-   **Allowed Redirect URLs:**
    `https://saikat-71.github.io/Football-League-Manager/**`

Add your local development URL only if you use one. The confirmation
email template must preserve Supabase's confirmation URL (commonly
`{{ .ConfirmationURL }}`) so the configured redirect can be applied.

After a user confirms their email, the app is intended to return to the
website and show the login screen. Test this using a newly registered
account and the actual email delivered by your Supabase project.

## Mobile Home Screen installation

The project includes a web manifest and a Touchline icon reference.

-   **iPhone/iPad:** Open the deployed website in Safari → tap **Share**
    → **Add to Home Screen** → **Add**.
-   **Android:** Open the website in Chrome → open the browser menu →
    **Install app** or **Add to Home screen**, depending on the browser.

Deploy the icon and manifest files before installing. If an old icon
remains, remove the existing Home Screen shortcut and add it again after
clearing the browser cache.

## Profile image and mobile logout

-   Open **My Profile** and choose **Choose image** to upload a JPG, PNG
    or WebP file up to 5 MB.
-   The image is resized and saved in the current browser's local
    storage. It is specific to that browser/device and can be lost if
    that site's local storage is cleared.
-   Use **Remove image** to clear it.
-   Signed-in mobile users should see **Logout/Sign out** in the mobile
    navigation. If it does not appear after deployment, refresh the
    page, sign in again, and verify that the updated `app.js` and
    `styles.css` were both uploaded.

## Testing checklist

Before using the website for a real league, test:

-   [ ] Public dashboard opens without requiring login.
-   [ ] Sign-in and registration links open the correct screens.
-   [ ] Email confirmation returns to the intended website URL.
-   [ ] Admin and regular-user permissions behave correctly.
-   [ ] A new account can be approved by an Admin.
-   [ ] Bundled import creates players only and leaves team ownership
    empty.
-   [ ] Re-running the import skips existing matching players.
-   [ ] Profile image upload and removal work on desktop and mobile.
-   [ ] Sign-out is visible and works on a narrow mobile screen.
-   [ ] Home Screen shortcut displays the Touchline icon.
-   [ ] Auctions, transfers, fixtures and standings work with multiple
    test accounts.

## Security notes

-   Row Level Security (RLS) and database-side functions are important
    security boundaries; hiding a button in the UI is not sufficient
    authorization.
-   Never publish the Supabase `service_role` secret.
-   The public anon/publishable key is designed for frontend use only
    when database policies are configured correctly.
-   Avoid importing unreviewed spreadsheets into a production league
    database.
-   Take a database backup before major migrations or bulk imports.
-   The account archive workflow does not necessarily physically delete
    a Supabase Auth identity; privileged Auth operations require a
    trusted server-side environment.
-   Password recovery and background auction finalization may require
    additional configuration depending on the deployed version and
    Supabase project.

## Troubleshooting

**The page is blank or does not load** - Check the GitHub Pages
deployment status and confirm `index.html` is in the published root. -
Check browser developer tools for JavaScript errors. - Verify the file
paths and letter casing; GitHub Pages hosting is case-sensitive.

**Login or registration fails** - Confirm `data/config.js` has the
correct Supabase URL and public key. - Ensure Email/password
authentication is enabled. - Check Supabase Auth URL Configuration and
the email confirmation template. - Review Supabase logs for the exact
error.

**Player import fails** - Confirm you are signed in as an active
Admin. - Check that `supabase/schema.sql` has been run successfully. -
Confirm the spreadsheet contains a `Name` or `Player Name` header. -
Review the browser console and Supabase logs.

**The website works on Wi-Fi but not mobile data** - This can be caused
by DNS, carrier filtering, browser caching or network routing. Test
another network and DNS resolver, and check the domain's current
reachability independently. A successful Wi-Fi test alone does not prove
global availability.

## Validation status

The source files can be checked for syntax and archive integrity in a
development environment. This README does not claim that the live
Supabase backend, email confirmation, GitHub Pages deployment, database
security policies or real-device behavior have been verified. Test those
items in your own deployed environment before relying on the app for a
live competition.

## License

No license is specified in this repository. Add a `LICENSE` file if you
intend to grant others permission to reuse or redistribute the project.
