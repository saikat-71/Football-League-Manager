# Touchline Football League Manager — শুরু থেকে চালানোর গাইড (বাংলা)

এই ZIP-এ frontend, database schema এবং মূল Season 7 dataset আছে। Frontend GitHub Pages-এ চলবে; secure login, shared data এবং bidding/transfer-এর মতো sensitive operation চালাতে আলাদা Supabase backend লাগবে। **ZIP extract করলেই production login/auction চালু হবে না**—নিজের Supabase project configure করতে হবে।

## ধাপ ১ — ZIP extract

1. `Football-League-Manager-corrected.zip` extract করো।
2. Extract করা `Football-League-Manager-main` folder-এর মধ্যে `index.html`, `app.js`, `styles.css`, `data/`, `supabase/` থাকবে।
3. কোনো ফাইল আলাদা করে সরাবে না; folder structure একই রাখবে।

## ধাপ ২ — Supabase project তৈরি

1. https://supabase.com/ এ account/login করো।
2. **New project** নির্বাচন করে project name, database password এবং region নির্বাচন করো। Database password নিরাপদ জায়গায় রাখো।
3. Project তৈরি শেষ হওয়া পর্যন্ত অপেক্ষা করো।
4. Project dashboard থেকে **SQL Editor → New query** খোলো।
5. ZIP-এর `supabase/schema.sql` ফাইলটি editor-এ সম্পূর্ণ copy-paste করে **Run** করো।
6. Query সফল হয়েছে কি না দেখো। Error দেখালে সেটি না বুঝে এড়িয়ে যেও না; error text সংরক্ষণ করে troubleshoot করো।

## ধাপ ৩ — Supabase credentials frontend-এ বসানো

1. Supabase dashboard-এ **Project Settings → API** (বা API Keys section) খোলো।
2. Project URL এবং **anon/public/publishable key** কপি করো। UI-তে key-এর নাম version অনুযায়ী আলাদা হতে পারে।
3. `data/config.js` খুলে এই দুই placeholder replace করো:
   - `https://YOUR-PROJECT.supabase.co` → তোমার Project URL
   - `YOUR_SUPABASE_ANON_KEY` → তোমার public anon/publishable key
4. `appName` ও `currencyLabel` চাইলে পরিবর্তন করো।
5. **কখনোই `service_role` / secret key `data/config.js`, `app.js`, GitHub repository বা public frontend-এ বসাবে না।**

## ধাপ ৪ — Authentication settings

1. Supabase dashboard-এ **Authentication → Providers → Email** খোলো এবং email/password sign-in enable আছে নিশ্চিত করো।
2. **Authentication → URL Configuration**-এ Site URL হিসেবে `https://saikat-71.github.io/Football-League-Manager/` সেট করো।
3. Allowed Redirect URLs-এ `https://saikat-71.github.io/Football-League-Manager/**` যোগ করো। Email verification link click করলে app verification শেষ করে Football League Manager-এর login screen-এ ফেরত পাঠাবে; portfolio URL ব্যবহার করবে না।
4. Email confirmation চালু রাখলে registration-এর পর inbox-এর verification link follow করতে হবে। Invitation/confirmation mail ঠিকমতো পৌঁছাতে production-এ SMTP configure করতে হতে পারে।

## ধাপ ৫ — প্রথম Admin তৈরি

1. Frontend চালু করে **Create account** দিয়ে নিজের email, username, display name ও password দিয়ে account তৈরি করো।
2. Email confirmation enable থাকলে email verify করো।
3. Supabase **SQL Editor**-এ নিচের query চালাও। `YOUR_USERNAME`-এর জায়গায় registration-এর exact lowercase username দেবে:

```sql
update public.profiles
set role = 'admin', status = 'active'
where username = 'YOUR_USERNAME';
```

4. Query-তে `1 row` update হয়েছে কি না দেখো। Username ভুল হলে row update হবে না।
5. Website-এ sign out করে আবার sign in করো। এখন Admin navigation দেখা উচিত।
6. নিরাপত্তার জন্য প্রথম Admin তৈরি করার পর SQL Editor access ও database password নিরাপদ রাখবে। At least one active Admin account থাকতে হবে।

## ধাপ ৬ — GitHub-এ upload এবং GitHub Pages চালু

1. GitHub-এ নতুন repository তৈরি করো। Public repository GitHub Pages-এর জন্য সহজ, তবে Supabase security RLS-এর ওপর নির্ভর করে; frontend-এ secret রাখবে না।
2. Extract করা project folder-এর **ভেতরের সব ফাইল ও folder** repository root-এ upload করো—যাতে `index.html` repository root-এ থাকে, আবার ভেতরে আরেকটা project folder তৈরি না হয়।
3. GitHub repository → **Settings → Pages** খোলো।
4. **Build and deployment → Deploy from a branch** নির্বাচন করো। Branch `main`, folder `/(root)` নির্বাচন করে Save করো।
5. GitHub Pages-এর live URL তৈরি হলে সেটি Supabase Authentication URL Configuration-এ যোগ করো।
6. `data/config.js`-এ credentials বসানোর পর পরিবর্তিত ফাইলও commit/push করতে হবে।  

## ধাপ ৭ — Website থেকে Admin account control (কোনো Function deploy লাগবে না)

এই corrected build-এ routine Admin account management website থেকেই করা যায়। কোনো CLI, Node.js বা Edge Function deploy লাগবে না।

1. নতুন User website-এর **Create account** দিয়ে নিজের account তৈরি করবে।
2. নতুন account **User Accounts** page-এ `pending` হিসেবে দেখা যাবে।
3. Admin website থেকেই **Approve / Reject / Deactivate / Reactivate** করতে পারবে।
4. **Make Admin / Make User** action দিয়ে role পরিবর্তন করা যাবে; database RPC অন্তত একজন active Admin রেখে দেয় এবং audit log লিখে।
5. **Archive account** ব্যবহার করলে account app access হারায়, active bid/transfer বাতিল হয়, player free agent হয় এবং historical records থাকে। এটি Supabase Auth identity-কে physically delete করে না—ওটা নিরাপদে করতে privileged server-side Auth API প্রয়োজন।
6. নতুন User-কে invite করার জন্য আলাদা invitation email Function নেই। Website URL পাঠাও; User নিজে registration করবে এবং Admin approve করবে।

"সব দৈনন্দিন league/Admin control website-এ"—কিন্তু প্রথম Admin account bootstrap করার SQL ধাপ একবার প্রয়োজন। নিরাপত্তার জন্য frontend-এ service-role key কখনো যোগ করবে না।

## ধাপ ৮ — Excel থেকে শুধু Player List import

1. Admin account দিয়ে sign in করো।
2. **Settings & Audit** অথবা Dashboard-এ **Import players from Excel** চাপো।
3. `.xlsx`, `.xls` বা `.csv` ফাইল বেছে নাও; প্রথম worksheet পড়া হবে।
4. অন্তত `Name` বা `Player Name` column থাকতে হবে। Optional columns: `ID`, `Position`, `Rating`/`Overall`, `Age`, `Nationality`, `Base Price`/`Price`।
5. Imported সব player `free_agent` হবে এবং `owner_team_id` খালি থাকবে। **কোনো Team, Club, Ownership বা Budget import হবে না।** আগে থেকে থাকা player-এর ID বা name মিললে duplicate এড়াতে skip হবে।
6. Excel file এই conversation-এ attach করা হয়নি, তাই ওই sheet-এর নির্দিষ্ট player names ZIP-এ embed করা হয়নি। চাইলে Excel file এখানে upload করো; আমি list/column যাচাই করে দিতে পারব।

## ধাপ ৯ — প্রথমবারের test checklist

- [ ] Public visitor Players, Teams, Fixtures/standings দেখতে পারে।
- [ ] নতুন account pending থাকে এবং Admin approval ছাড়া transaction করতে পারে না।
- [ ] Approved User একটিমাত্র active team তৈরি করতে পারে।
- [ ] User অন্য User-এর private profile/transaction দেখতে পারে না।
- [ ] Admin player add/edit, player proposal review এবং team/account status manage করতে পারে।
- [ ] Auction countdown, minimum increment, multiple auctions, budget reserve, outbid এবং withdrawal যাচাই করো।
- [ ] Auction end হলে winning player assign হয় এবং winning amount একবারই ledger-এ যায়।
- [ ] Transfer-এ Buyer/Seller acceptance, ownership ও ledger একসঙ্গে update হয়।
- [ ] Fixture result correction audit history-তে দেখা যায় এবং standings recalculate হয়।
- [ ] Mobile, tablet এবং desktop-এ navigation/table/modal পরীক্ষা করো।
- [ ] Browser console এবং Supabase Logs-এ errors আছে কি না দেখো।

## গুরুত্বপূর্ণ সীমাবদ্ধতা ও সতর্কতা

- এই workspace-এ তোমার Supabase credentials নেই, তাই live database connection, email delivery, actual RLS runtime, simultaneous multi-user bidding এবং GitHub Pages deployment এখানে verify করা সম্ভব হয়নি।
- Auction expiry authenticated client polling-এর সময় resolve হয়। Unattended exact background resolution চাইলে Supabase project-এ `pg_cron` available/enable করে README-র SQL schedule setup করতে হবে।
- Production-এ যাওয়ার আগে Supabase database backup, Auth email delivery, RLS, account archive, bid race conditions এবং transfer settlement পরীক্ষা করো।
- `data/config.js`-এ শুধু public key থাকবে। Service-role secret leak হলে সেটি Supabase dashboard থেকে rotate করো।
- Supabase free-tier quotas/pricing পরিবর্তিত হতে পারে; production ব্যবহারের আগে বর্তমান plan limits দেখে নাও।


## নতুন পরিবর্তন — Public dashboard, Home Screen logo ও Player import

- Website খুললে প্রথমে **public dashboard** দেখাবে; login বাধ্যতামূলক নয়। Dashboard-এর sidebar/top bar থেকে **Sign in** বা **Register** বেছে নেওয়া যাবে।
- ফোনে Safari/Chrome থেকে **Add to Home Screen** করলে Touchline logo icon হিসেবে দেখানোর জন্য `manifest.webmanifest`, `apple-touch-icon` ও favicon যোগ করা হয়েছে।
- Excel-এর **Auction Players with Positions** worksheet থেকে 184 জন unique player-এর নাম, rating ও primary position `data/player-list.json`-এ রাখা হয়েছে।
- Supabase database-এ player-গুলো যুক্ত করতে প্রথমে Admin account দিয়ে sign in করো, তারপর **Settings & Audit** বা Dashboard থেকে **Import bundled 184-player list** চাপো। Confirm করলে missing players-গুলো free agent হিসেবে insert হবে।
- কোনো Team/Club তৈরি হবে না, player ownership assign হবে না, team budget import হবে না। যেসব player আগে থেকেই database-এ আছে, নাম/ID মিললে duplicate import এড়িয়ে যাবে।
- Excel sheet-এ age/nationality/base price নির্ভরযোগ্যভাবে দেওয়া ছিল না, তাই imported records-এ age/nationality ফাঁকা এবং base price `1` রাখা হয়েছে। Admin পরে player edit করে base price ঠিক করতে পারবে।
- এই import action database-এ নিজে থেকে চালানো হয়নি; Supabase credentials ও active Admin permission প্রয়োজন। ZIP-এ player list bundled এবং import button প্রস্তুত আছে।
