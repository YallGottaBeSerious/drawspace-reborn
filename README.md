# drawspace.reborn

A dark, Drawspace-inspired social community starter built with Vite + vanilla JavaScript + Supabase.

## Included
- Email/password registration and login, with a username profile
- Profile directory with username search and sorting (newest, last active, username, random)
- Friend requests and friend list
- Friend-only wall posts
- Crush nominations and 1–10 ratings
- Gold/ruby wallet display and leaderboard categories
- Notifications
- VIP room creation and room directory
- World Boss chat-stamina damage loop, progress/reward claim UI
- Profile gallery metadata/upload UI
- Secret-message inbox UI
- Staff role display and moderation actions (server-checked)
- Developer-only bot profile creation

## Run locally
1. Create a Supabase project.
2. In Supabase SQL Editor, run `supabase/schema.sql`.
3. Copy `.env.example` to `.env` and fill in your Supabase project URL and **anon/publishable** key.
4. Run `npm install`, then `npm run dev`.
5. Open the local URL printed by Vite.

## Deploy to GitHub + Vercel
Push this folder to a GitHub repository. Import it into Vercel and add the two `VITE_SUPABASE_*` environment variables in Project Settings.

## Important security notes
- Never put a Supabase `service_role` key in browser code or GitHub.
- This is a starter implementation. Supabase Auth handles passwords; the app never stores plaintext passwords.
- Roles are stored in a protected table and can only be assigned by trusted server-side tooling / SQL by the project owner. Do not expose role assignment to regular users.
- Kick/ban are audited moderation actions. A website cannot forcibly disconnect someone from an unrelated third-party service.
- World Boss, wallet rewards, ratings, and leaderboard writes should be moved to Edge Functions before a public launch. The included SQL restricts sensitive tables with RLS; this starter uses safe server-side RPC patterns for privileged actions where practical.
- Add CAPTCHA, email verification, rate limits, reporting/blocking, age-appropriate safety controls, and a privacy policy before opening registration publicly.

## First admin
After you register your own account, find its UUID in Supabase Authentication > Users and run:
```sql
insert into public.staff_roles(user_id, role)
values ('YOUR-AUTH-USER-UUID', 'developer')
on conflict (user_id) do update set role = excluded.role;
```
This is a manual owner-controlled operation, not an in-app self-service feature.
