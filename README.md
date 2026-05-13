# Caddy Upload Server — Railway Template

A production-ready, HTTPS-first file-upload server built with
[Caddy](https://caddyserver.com) +
[caddyv2-upload](https://github.com/git001/caddyv2-upload) and
deployed on [Railway](https://railway.com).

---

## Repository layout

```
.
├── Caddyfile          # Caddy configuration (upload, auth, headers, health check)
├── Dockerfile         # Two-stage build: xcaddy compiles the upload plugin
├── railway.json       # Railway build/deploy config (builder, restart, health check)
├── public/
│   └── index.html     # Landing page served at /
└── README.md
```

---

## How it works

| Path | Method | Auth | Description |
|---|---|---|---|
| `/` | GET | — | Public landing page |
| `/upload` | GET | Basic Auth | Shows the HTML upload form |
| `/upload` | POST | Basic Auth | Receives `multipart/form-data` upload |
| `/uploads/*` | GET | — | Publicly browse/download uploaded files |
| `/health` | GET | — | Health probe (returns `200 OK`) |

The Dockerfile uses a **two-stage build**:

1. **`caddy:2-builder`** — runs `xcaddy` to compile a custom Caddy binary with the `caddyv2-upload` plugin baked in.
2. **`caddy:2-alpine`** — swaps in that binary for a minimal final image.

---

## Deploying to Railway

### Step 1 — Push to GitHub

Create a new (private) repository and push these files to it.

### Step 2 — Create the Railway project

1. Log into [railway.com](https://railway.com).
2. Click **New Project → Deploy from GitHub repository** and select your repo.
3. Railway detects the `Dockerfile` and `railway.json` automatically and starts the build.

### Step 3 — Set the required environment variable

Navigate to your service → **Variables** and add:

| Variable | Value |
|---|---|
| `BASIC_AUTH_PASSWORD_HASH` | bcrypt hash of your chosen password (see below) |

> **Generate your hash** — run one of these locally:
> ```
> # If you have Caddy installed:
> caddy hash-password --plaintext "your-secret-password"
>
> # Or with Docker (no local install needed):
> docker run --rm caddy:2-alpine caddy hash-password --plaintext "your-secret-password"
> ```
> Paste the resulting `$2a$…` string as the variable value.

### Step 4 — Attach a persistent Volume

> ⚠️ Railway does **not** support defining volumes in `railway.json`.
> They must be created through the dashboard.

1. In your project canvas, right-click → **Add Volume**, or use **⌘K → New Volume**.
2. When prompted, select your Caddy service.
3. Set the **Mount Path** to `/srv/uploads`.
4. Save — Railway will redeploy the service with the volume attached.

Without a volume, uploaded files live only in the container and will be lost on the next deploy.

### Step 5 — Generate a public domain

In your service settings click **Generate Domain**.
Railway provisions a free `*.up.railway.app` subdomain with automatic TLS.

---

## Using the upload API

### Browser

Visit `https://your-domain.up.railway.app/upload`, enter your credentials, pick a file, and click **Upload**.

### curl

```
# Upload a file
curl -u admin:your-secret-password \
     -F "myFile=@/path/to/file.txt" \
     https://your-domain.up.railway.app/upload

# List uploaded files
curl https://your-domain.up.railway.app/uploads/
```

### Python (requests)

```python
import requests

url  = "https://your-domain.up.railway.app/upload"
auth = ("admin", "your-secret-password")

with open("report.pdf", "rb") as f:
    resp = requests.post(url, auth=auth, files={"myFile": f})

print(resp.status_code, resp.text)
```

---

## Configuration reference

### Upload limits

Edit these two values in `Caddyfile` → `upload @post { ... }`:

| Directive | Default | Description |
|---|---|---|
| `max_filesize` | `50MB` | Maximum size of a single uploaded file |
| `max_form_buffer` | `50MB` | Maximum in-memory buffer per request |

### Disable public file listing

Remove (or comment out) the `handle /uploads/*` block in the `Caddyfile` to
prevent unauthenticated users from browsing or downloading uploaded files.

### Restrict allowed file types

Add a `file_field_name` filter or use a Caddy `route` block with an `expression`
matcher to reject files whose names don't end with an allowed extension, e.g.:

```caddyfile
@bad_ext {
    path_regexp ext \.(php|sh|exe|bat)$
}
error @bad_ext "File type not allowed" 403
```

Place that block **inside** the `handle /upload { … }` block, before the `upload` directive.

### Use a different username

Replace `admin` in the `basic_auth` block with any username you like.
The `BASIC_AUTH_PASSWORD_HASH` variable holds the hash for that user.

---

## Security checklist

- [x] HTTPS enforced automatically by Caddy + Railway's edge
- [x] Password protected via HTTP Basic Auth with bcrypt
- [x] Password hash stored as an environment variable, never hard-coded
- [x] Security headers (`HSTS`, `X-Frame-Options`, `nosniff`, `XSS-Protection`)
- [x] Server fingerprinting suppressed (`-Server` header)
- [x] File-size limit enforced by the upload plugin
- [ ] **Change the default password hash** before deploying
- [ ] Restrict allowed file extensions if your use-case allows it
- [ ] Consider removing `/uploads/*` public listing for sensitive uploads
