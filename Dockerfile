# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – Build a custom Caddy binary with the file-upload plugin
# ─────────────────────────────────────────────────────────────────────────────
FROM caddy:2-builder AS builder

# xcaddy compiles Caddy from source and injects the requested plugins.
# Plugin source: https://github.com/git001/caddyv2-upload
RUN xcaddy build \
    --with github.com/git001/caddyv2-upload \
    --with github.com/caddyserver/replace-response

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – Minimal production image
# ─────────────────────────────────────────────────────────────────────────────
FROM caddy:2-alpine

# Swap the stock Caddy binary for our plugin-enabled one
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Create the directory layout Caddy expects:
#   /srv/public   → static files served at /
#   /srv/uploads  → destination for uploaded files (mount a Railway Volume here)
RUN mkdir -p /srv/public /srv/uploads

# Drop in the Caddyfile and any bundled public assets
COPY Caddyfile /etc/caddy/Caddyfile
COPY public/   /srv/public/

# Railway dynamically assigns $PORT; the Caddyfile binds to it at runtime.
# We document 8080 as the conventional default here.
EXPOSE 8080
