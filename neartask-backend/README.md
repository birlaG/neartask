# NearTask Backend

MVP API for the hyperlocal task/gig marketplace described in the PRD — NestJS + TypeScript, PostgreSQL/PostGIS via Prisma, JWT auth. Built to match the PRD's decisions:

- Wallet is an append-only ledger, two balances (Available / Locked) — §6.6
- Funds lock at task-posting time, not at selection — §6.6
- Refund table implemented exactly: 95% pre-accept, 0% post-accept, 100% on doer no-show — §6.6
- Withdrawal is a **manual** flow: the app never moves real money out on its own, it only creates a PENDING request for an admin to action — §6.6
- Social-gig gating: VERIFIED tier minimum, gender/age preferences blocked on CHORE tasks — §8

## What's built vs. what's next

**Built (this scaffold):**
- Full data model (`prisma/schema.prisma`)
- Auth (register/login, JWT)
- Wallet: top-up, balance, transaction history, withdrawal request, admin payout confirmation
- Tasks: create (locks funds), nearby feed (PostGIS), apply, select applicant, complete, cancel, no-show
- Users: `me` profile endpoint
- Admin: withdrawal queue + mark-paid, KYC review queue + approve/reject, dispute resolution queue, dashboard stats
- Ratings: either party on a completed task can rate the other once; recomputes the rated user's `trustScore` as the average of ratings received
- Disputes: either party can raise one while a gig is selected/in-progress; an admin resolves it (release to doer or refund creator) — funds stay locked until then, never auto-released
- KYC: users upload an ID document + selfie (multipart), stored via a swappable storage driver (local disk for dev, any S3-compatible bucket for prod — Contabo Object Storage included); admin reviews the actual documents, not just a status flag
- Admin panel (`/admin-panel/index.html`) — a single self-contained HTML/JS page that talks to the API above. No build step, no framework — open it in a browser or drop it on any static host.

**Not yet built — next milestones:**
- Real payment gateway webhook integration (Razorpay/Cashfree) — the `topup` endpoint currently trusts a client-supplied amount, which is fine for local testing only; production needs signature-verified webhooks
- Automated ID/selfie liveness matching (currently 100% human review, which is fine at MVP volume)
- Chat / live-location (Socket.io, per §12.4)
- Content moderation hooks for SOCIAL task descriptions (§8)
- Rate limiting, request logging, structured error responses
- The Flutter mobile app itself — this backend is what it will call

## Local development

Requires Node 20+, Docker.

```bash
cp .env.example .env
docker compose up -d postgres redis
npm install
npm run prisma:migrate    # creates the database schema
npm run start:dev
```

The API listens on `http://localhost:3000`.

## Running in GitHub Codespaces

A `.devcontainer/devcontainer.json` is included — push this to a GitHub repo, click "Create codespace", and it'll open with Node 20, Docker-in-Docker, and the Prisma/ESLint/Prettier extensions pre-installed. Once it's open:

```bash
docker compose up -d postgres redis
npm run prisma:migrate
npm run start:dev
```

Codespaces auto-forwards port 3000; the "Ports" tab in VS Code gives you the public URL if you want to hit the API from outside the codespace (e.g. from the Flutter app's `--dart-define=API_BASE_URL=...`, or from a phone).

### One manual step after the first migration

Prisma doesn't manage PostGIS extensions or geography columns. Run this once against your database after the first migration:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

The `findNearby` query in `tasks.service.ts` works off the existing `latitude`/`longitude` float columns using `ST_MakePoint` on the fly, so no schema change is required to get started. For better query performance once task volume grows, add a dedicated `geography(Point,4326)` column and a GiST index, and switch the query to use it directly.

## Deploying to your Contabo VPS

1. Point a domain/subdomain at the VPS IP.
2. Install Docker + Docker Compose on the VPS.
3. Copy this repo to the server, set real secrets in `.env` (especially `JWT_SECRET`).
4. `docker compose up -d --build`
5. Put Nginx in front of it as a reverse proxy, and use Certbot for a free Let's Encrypt SSL cert.
6. Set up a cron job or systemd timer for nightly `pg_dump` backups pushed to off-server object storage — don't rely on Contabo snapshots alone for financial ledger data (see PRD §12.7).

## File storage (KYC documents)

Controlled by `STORAGE_DRIVER` in `.env`:
- **`local`** (default) — saves to `./uploads`, served statically at `/uploads/...` by the API itself. Fine for local development. **Do not use this in production** — it's a public, unauthenticated static route serving ID documents and selfies, which is exactly the kind of thing that shouldn't be world-readable.
- **`s3`** — uploads to any S3-compatible bucket. Works with Contabo Object Storage, Backblaze B2, Cloudflare R2, or AWS S3 — set `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` in `.env`. Before going live, make the bucket **private** and switch the admin panel / API to generate short-lived signed URLs rather than public object links (not implemented in this scaffold — flagging it so it isn't missed).

## Admin access

There's no public "become an admin" endpoint, by design. Bootstrap your first admin manually:

1. Register a normal account through `/auth/register` (or the panel's login screen won't have anyone to log in as yet — register first, then promote).
2. Promote it directly in the database:
   ```sql
   UPDATE "User" SET role = 'ADMIN' WHERE phone = '+91XXXXXXXXXX';
   ```
   (Use `npm run prisma:studio` for a GUI instead of raw SQL, if you prefer.)
3. Open `admin-panel/index.html` in a browser (edit the `API_BASE` constant at the top of the file first if your API isn't on `http://localhost:3000`), and log in with that account.

The panel covers the withdrawal queue and KYC review — the two manual processes you said you'd run yourself — plus a basic stats dashboard.

## API overview

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Get JWT |
| GET | `/users/me` | Own profile |
| PATCH | `/users/me` | Update profile / privacy setting |
| POST | `/kyc/submit` | Upload ID document + selfie (multipart: `idDocument`, `selfie`) |
| GET | `/kyc/me` | Your latest KYC submission + status |
| GET | `/wallet/balance` | Available + locked balance |
| GET | `/wallet/transactions` | Full ledger history |
| POST | `/wallet/topup` | Add money (dev-only trust; needs gateway webhook in prod) |
| POST | `/wallet/withdraw` | Request payout (manual, admin-actioned) |
| POST | `/tasks` | Post a gig (locks funds) |
| GET | `/tasks/nearby?lat=..&lng=..&radius=..` | Discovery feed |
| GET | `/tasks/:id` | Task detail + applications |
| POST | `/tasks/:id/apply` | Apply to a gig |
| POST | `/tasks/:id/select/:applicationId` | Creator picks one applicant |
| POST | `/tasks/:id/complete` | Release funds to doer |
| POST | `/tasks/:id/cancel` | Cancel, refund per policy |
| POST | `/tasks/:id/no-show` | Full refund + doer trust strike |
| POST | `/tasks/:id/rate` | Rate the other party on a completed task |
| POST | `/tasks/:id/dispute` | Raise a dispute (SELECTED/IN_PROGRESS only) |
| GET | `/admin/tasks/disputed` | Disputed tasks *(admin only)* |
| POST | `/admin/disputes/:taskId/resolve` | Resolve — release to doer or refund creator *(admin only)* |
| GET | `/admin/stats` | Dashboard counts *(admin only)* |
| GET | `/admin/withdrawals/pending` | Withdrawal queue *(admin only)* |
| POST | `/admin/withdrawals/:id/mark-paid` | Confirm manual payout sent *(admin only)* |
| GET | `/admin/kyc/pending` | KYC review queue *(admin only)* |
| PATCH | `/admin/kyc/:submissionId` | Approve/reject a KYC submission *(admin only)* |

All endpoints except `/auth/*` require `Authorization: Bearer <token>`.
