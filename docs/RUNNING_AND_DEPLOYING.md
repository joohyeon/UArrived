# Running and deploying UMadeIt

UMadeIt is one Jac web app (`jac.toml` → `kind = "web-app"`, entry `main.jac`) that's
**mobile-first responsive** — there's no separate native mobile project. "Testing on mobile"
means loading the same app at phone width, either in a resized browser or on an actual phone.

---

## 1. Run the web app locally

```bash
bash scripts/setup.sh                  # one-time: installs deps (works around the macOS venv bug)
cp .env.example .env                   # then fill in values you need (see below)
UARRIVED_DEV_MODE=1 jac run --dev main.jac
```

- **App:** http://localhost:8000 · **API:** http://localhost:8001
- `--dev` gives hot reload (HMR) — edits to any `.jac` file refresh the running app.
- `UARRIVED_DEV_MODE=1` skips real email verification: signup returns the verification token
  directly instead of emailing it, so you can sign up and verify without SMTP configured. Never
  set this in the pilot/production.
- Useful `.env` values for local work: `ANTHROPIC_API_KEY` (drafting/Help-me-decide won't work
  without it), `UARRIVED_MODERATORS` (comma-separated `@umich.edu` addresses that can access
  `/market` moderation), `UARRIVED_TODAY` isn't a real var — use the clock override documented in
  `CLAUDE.md` (`UARRIVED_TODAY=YYYY-MM-DD`) if you need to move the server's notion of "today"
  forward to test expiry.
- Stop the server with `Ctrl-C`. If a stale server is holding the project's database, add
  `--takeover` to evict it: `jac run --dev --takeover main.jac`.

Quick sanity check without clicking through the UI:

```bash
jac run --faux main.jac                # prints every served endpoint, no server started
```

---

## 2. Test the mobile view locally

The app is the same code and the same server; only the viewport changes.

### a) Resized desktop browser (fastest)

Open http://localhost:8000 in Chrome and either shrink the window to ~360–390px wide, or open
DevTools → the device toolbar (Cmd+Shift+M) and pick a phone preset (iPhone 14, Pixel 7, ...).

### b) Headless snapshot at phone width (scriptable, no manual resizing)

```bash
jac browse open localhost:8000 -v 390x844   # iPhone-ish viewport
jac browse snapshot                          # accessibility tree with @e1/@e2 refs
jac browse click @e5                         # drive it like a real user
```

This is what `/verify` uses to QA a change at phone width before desktop.

### c) A real phone on the same Wi-Fi

By default the dev server only listens on the machine that started it. Bind it to your LAN
interface instead:

```bash
UARRIVED_DEV_MODE=1 jac run --dev --host 0.0.0.0 main.jac
```

Find your machine's LAN IP and open `http://<that-ip>:8000` in the phone's browser (phone and
laptop must be on the same network):

```bash
# macOS
ipconfig getifaddr en0        # e.g. 10.0.0.4 -> http://10.0.0.4:8000
```

If the phone can't connect, check the laptop's firewall isn't blocking incoming connections on
port 8000, and that the phone isn't on a guest/isolated Wi-Fi network.

---

## 3. Deploy to make it public

Pick based on how permanent you need the URL to be. `jac run` exits the moment its stdin closes,
so any of these must background it properly (a tunnel command, `nohup`, or a process manager) —
plain `jac run --dev &` in an interactive shell will die when the terminal closes.

### a) Fastest — a temporary public URL for a demo (minutes, no infra)

Run the server normally, then tunnel it:

```bash
UARRIVED_DEV_MODE=1 jac run --dev main.jac &
cloudflared tunnel --url http://localhost:8000     # or: ngrok http 8000
```

You get a random public HTTPS URL that forwards to your laptop. Fine for a demo; it dies when
you stop the tunnel or the laptop sleeps, and it's still `UARRIVED_DEV_MODE`, so don't share real
student data through it.

### b) A small VM you own (persistent URL, still simple)

1. Provision any small Linux VM (a $5–6/mo box is enough for a pilot) and point a DNS A/CNAME
   record at it.
2. On the VM:
   ```bash
   curl -fsSL https://jaclang.org/install.sh | bash -s -- --version 0.37.23
   git clone <your repo> uarrived && cd uarrived
   jac install
   ```
3. Create a real `.env` (never commit it): set real `ANTHROPIC_API_KEY`, SMTP creds
   (`SMTP_HOST`/`SMTP_USER`/`SMTP_PASSWORD`/`SMTP_FROM`), `UARRIVED_PUBLIC_URL=https://your-domain`,
   `UARRIVED_MODERATORS`, `UARRIVED_BLOCK_SALT` (set once, never rotate — rotating forgets existing
   blocks), and **leave `UARRIVED_DEV_MODE` unset/0**.
4. Set a real auth signing secret so sessions don't rely on a per-process generated one — add to
   `jac.toml`:
   ```toml
   [serve.auth]
   secret = "${JAC_SERVE_AUTH_SECRET}"     # export a long random string in the VM's environment
   ```
5. Put a reverse proxy (Caddy is the least config) in front for TLS + port 443 → 8000:
   ```
   your-domain.com {
       reverse_proxy localhost:8000
   }
   ```
6. Run the app as a service so it survives reboots and detaches from any terminal (`jac run`
   exits when stdin closes, so daemonize it):
   ```ini
   # /etc/systemd/system/uarrived.service
   [Service]
   WorkingDirectory=/home/you/uarrived
   ExecStart=/root/.local/bin/jac run --profile prod main.jac
   Restart=always
   StandardInput=null
   [Install]
   WantedBy=multi-user.target
   ```
   ```bash
   systemctl enable --now uarrived
   ```
7. Before going live, disable API docs/introspection for production in `jac.toml`:
   ```toml
   [serve]
   docs_enabled = false
   graph_enabled = false
   ```

### c) Kubernetes via `jac scale` (the built-in production path, if you already have a cluster)

Needs a Kubernetes cluster you can already reach with `kubectl` (or a cloud target jac can
provision against). Add to `jac.toml`:

```toml
[scale.kubernetes]
app_name = "uarrived"
namespace = "production"
domain = "your-domain.com"
cert_manager_email = "you@example.com"
min_replicas = 1
max_replicas = 3
cpu_request = "250m"

[scale.secrets]
ANTHROPIC_API_KEY = "${ANTHROPIC_API_KEY}"
SMTP_PASSWORD = "${SMTP_PASSWORD}"
JAC_SERVE_AUTH_SECRET = "${JAC_SERVE_AUTH_SECRET}"   # must be set — otherwise the cluster falls
                                                       # back to a shipped placeholder secret
```

```bash
jac scale deploy main.jac --dry-run --show-yaml   # lints config + prints manifests; touches nothing
jac scale deploy main.jac                         # deploys (source ships to the cluster on a PVC)
jac scale status main.jac                         # app / Postgres / Prometheus / Grafana health
```

HTTPS is a two-step: deploy plain first, point your domain's CNAME at the printed load-balancer
hostname, then re-run with TLS:

```bash
jac scale deploy main.jac --enable-tls
```

**Careful:** `jac scale destroy main.jac` deletes the namespace *and its persistent volumes* —
there's a y/N prompt and no undo. Postgres is provisioned automatically as a StatefulSet; don't
run this against a cluster with data you care about without checking first.

---

## Production checklist (any of the above)

- [ ] `UARRIVED_DEV_MODE` unset (verification tokens must go out by real email, not in the response)
- [ ] Real SMTP configured (`SMTP_HOST`/`SMTP_USER`/`SMTP_PASSWORD`/`SMTP_FROM`)
- [ ] `UARRIVED_PUBLIC_URL` set to the real public URL (used in emailed links)
- [ ] A real, non-default `[serve.auth] secret` / `JAC_SERVE_AUTH_SECRET` set
- [ ] `docs_enabled = false`, `graph_enabled = false` under `[serve]`
- [ ] `.env` never committed; secrets injected via the platform's own secret mechanism
