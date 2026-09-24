# Running NearTask (backend + app) in one GitHub Codespace

## 1. Put everything in one repo

1. Create a new (empty) GitHub repo — e.g. `neartask`.
2. On your machine, unzip both downloads so you end up with this layout:
   ```
   neartask/
     neartask-backend/       ← from neartask-backend.zip
     neartask_app/           ← from neartask_app.zip
     .devcontainer/          ← the two files from this setup package
       devcontainer.json
       post-create.sh
   ```
3. Push it:
   ```bash
   cd neartask
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/<you>/neartask.git
   git push -u origin main
   ```

## 2. Open it in Codespaces

On the repo's GitHub page: **Code → Codespaces → Create codespace on main**.

First boot takes a few minutes — it's installing Node, Docker-in-Docker, and cloning the Flutter SDK (~2–3 GB) via `post-create.sh`. Grab a coffee.

## 3. Start the backend

Open a terminal in the codespace:

```bash
cd neartask-backend
docker compose up -d postgres redis
npm run prisma:migrate     # creates the schema — you'll be prompted for a migration name, any name is fine
npm run start:dev
```

You should see `NearTask API running on port 3000`. Codespaces auto-forwards it — check the **Ports** tab in VS Code, you'll see a row for port 3000 with a forwarded URL like:
```
https://<random-name>-3000.app.github.dev
```
**Copy that URL** — you'll need it in the next two steps. Also **set port 3000's visibility to "Public"** in the Ports tab (right-click → Port Visibility → Public) — otherwise the Flutter web preview and admin panel can't reach it from your browser.

## 4. Create your admin account

In a **second terminal**:

```bash
# register a normal account via the running API
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999","name":"Admin","password":"changeme123"}'
```

Then promote it to admin:

```bash
cd neartask-backend
npm run prisma:studio
```

Prisma Studio opens on another forwarded port — find the `User` table, find the account you just registered, change `role` from `USER` to `ADMIN`, save.

## 5. Open the admin panel

The admin panel is a static HTML file — easiest way to serve it in a codespace:

```bash
cd neartask-backend/admin-panel
python3 -m http.server 5000
```

Open the forwarded port 5000 URL. Before logging in, edit `API_BASE` at the top of `index.html` to your **port 3000 forwarded URL** from step 3 (not `localhost` — that won't resolve from your browser tab, which is running outside the codespace). Save, refresh, log in with the admin account from step 4.

## 6. Run the app (Flutter Web preview)

In a **third terminal**:

```bash
source ~/.bashrc   # picks up the Flutter PATH from setup, if this is a fresh terminal
cd neartask_app
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=API_BASE_URL=https://<your-port-3000-forwarded-url>
```

Open the forwarded port 8080 URL. **Set its visibility to Public too**, same as port 3000.

Remember from the app's own README: this is the **web preview**, not a real mobile test. Location and photo capture behave differently in a browser than on a real phone — use Chrome DevTools' device emulation (F12 → toggle device toolbar) to at least get a phone-shaped viewport, and expect to grant location permission via the browser prompt instead of a native one.

## 7. What "it's working" looks like

- Register a second account in the app (or via `curl`, like step 4) — this is your test "doer."
- Log in as your first account, post a gig — you should see your wallet balance get rejected (insufficient balance) unless you top up first. Use the Wallet tab's "Add money" (it's a simulated top-up in this build, no real gateway yet).
- Log in as the second account, apply to the gig.
- Back on the first account, select the applicant, then mark it complete.
- Check the second account's wallet — the payout (minus commission) should be there.
- Check the admin panel's Withdrawals tab after requesting a withdrawal as the second account.

If all of that works, the wiring is sound end to end — wallet, tasks, and the app talking to the real API, not just three separate things that happen to compile.

## Notes / gotchas

- **Every time you reopen the codespace**, `docker compose up -d postgres redis` and `npm run start:dev` need to be started again (containers stop when the codespace does) — they don't auto-persist across sessions.
- **Codespaces free tier is 60–120 core-hours/month** — stop the codespace when you're done (Codespaces list → "..." → Stop codespace) rather than leaving it running.
- If port URLs stop matching what's in `API_BASE_URL` (e.g. after restarting the codespace, which can generate a new forwarded URL), just re-run the `flutter run` command with the new URL, and re-edit `admin-panel/index.html`.
