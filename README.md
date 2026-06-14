# codex-warmup

A small Docker container for triggering a scheduled `codex exec` warmup call.

The container is designed for platforms like Dokploy where you want a long-running idle container, then use the platform scheduler to run:

```bash
/usr/local/bin/codex-warmup
```

The script:

* writes Codex auth into `$HOME/.codex/auth.json`
* writes a minimal `$HOME/.codex/config.toml`
* runs a tiny `codex exec` prompt
* optionally emails you the result via Resend

---

## Why this exists

Codex sessions/windows can be time-based. This container lets you trigger a tiny scheduled Codex call before or during your workday so that session timing lines up better with your actual working blocks.

The container itself does **not** schedule anything. Scheduling is handled by Dokploy, cron, or another scheduler.

---

## Files

```text
codex-warmup/
├── Dockerfile
├── codex-warmup.sh
├── .env.example
└── README.md
```

---

## Required configuration

### `OPENCODE_AUTH_JSON`

The container needs your OpenAI OAuth credentials (as used by `opencode`) as an environment variable:

```env
OPENCODE_AUTH_JSON=...
```

Generate it from your local `opencode` login (`opencode auth login` against OpenAI, if not already done):

```bash
jq -c '.openai' ~/.local/share/opencode/auth.json
```

Copy the output and set it as `OPENCODE_AUTH_JSON` in your deployment environment.

Examples:

* Dokploy application environment variable
* Docker `--env-file`
* CI/CD secret
* Server scheduler secret

> **Security warning:** `OPENCODE_AUTH_JSON` contains OpenAI authentication tokens. Treat it like a password. Never commit it to Git. The access token expires periodically; `opencode` refreshes it automatically using the refresh token, but if the refresh token itself is ever revoked you'll need to regenerate and re-paste this value.

---

## Optional email notifications

Email notifications use [Resend](https://resend.com).

Set these environment variables if you want success/failure emails:

```env
RESEND_API_KEY=re_xxxxx
NOTIFY_EMAIL=you@example.com
FROM_NAME=Codex Warmup
FROM_EMAIL_ADDRESS=codexwarmup@iamt12e.co.zw
```

| Variable             | Description                                       |
| -------------------- | ------------------------------------------------- |
| `RESEND_API_KEY`     | Your Resend API key                               |
| `NOTIFY_EMAIL`       | The inbox that receives warmup notifications      |
| `FROM_NAME`          | Sender display name shown in Gmail/mail clients   |
| `FROM_EMAIL_ADDRESS` | Sender address. Must use a verified Resend domain |

If any notification variable is missing, the warmup still runs, but email notifications are skipped.

---

## Example `.env.local`

```env
OPENCODE_AUTH_JSON={"paste":"your-compact-auth-json-here"}

RESEND_API_KEY=re_xxxxx
NOTIFY_EMAIL=you@example.com

FROM_NAME=Codex Warmup
FROM_EMAIL_ADDRESS=codexwarmup@iamt12e.co.zw
```

Do not commit `.env.local`.

---

## Build locally

```bash
docker build --pull=false -t codex-warmup:test .
```

---

## Run locally

```bash
docker run --rm -it \
  --env-file .env.local \
  codex-warmup:test \
  /usr/local/bin/codex-warmup
```

Expected output includes:

```text
[codex-warmup] ... starting
OpenAI Codex ...
user
hi
codex
hi
[codex-warmup] ... done
```

If email notifications are configured, you should also receive an email.

---

## Test script changes without rebuilding

When only `codex-warmup.sh` changes, do not rebuild the image. Mount the local script into the container:

```bash
docker run --rm -it \
  --env-file .env.local \
  -v "$PWD/codex-warmup.sh:/usr/local/bin/codex-warmup:ro" \
  codex-warmup:test \
  bash -lc "bash /usr/local/bin/codex-warmup"
```

Use this while editing notification text or script logic.

Rebuild only when the `Dockerfile` changes.

---

## Manual trigger in a running container

If the container is already running, execute the warmup script inside it:

```bash
docker exec -it <container-name-or-id> /usr/local/bin/codex-warmup
```

---

## Dokploy deployment

Deploy this as a Dockerfile application.

Recommended Dokploy settings:

| Setting             | Value                            |
| ------------------- | -------------------------------- |
| Build type          | Dockerfile                       |
| Docker file         | `Dockerfile`                     |
| Docker context path | `.`                              |
| Build stage         | blank                            |
| Domain              | none needed                      |
| Port                | none needed if Dokploy allows it |

The container uses:

```dockerfile
CMD ["tail", "-f", "/dev/null"]
```

So it stays alive and waits for scheduled jobs.

---

## Dokploy environment variables

Add these under the application’s runtime **Environment Settings**:

```env
OPENCODE_AUTH_JSON=...
RESEND_API_KEY=...
NOTIFY_EMAIL=...
FROM_NAME=Codex Warmup
FROM_EMAIL_ADDRESS=codexwarmup@iamt12e.co.zw
```

Do not put these under build-time arguments or build-time secrets. The script needs them at runtime.

After changing environment variables, redeploy the application.

---

## Dokploy schedules

Create schedules that run this command:

```bash
/usr/local/bin/codex-warmup
```

Example daily schedule for Harare/Zimbabwe time:

| Purpose              |          Cron | Timezone        | Command                       |
| -------------------- | ------------: | --------------- | ----------------------------- |
| Pre-work warmup      |   `0 5 * * *` | `Africa/Harare` | `/usr/local/bin/codex-warmup` |
| Morning reset warmup |  `7 10 * * *` | `Africa/Harare` | `/usr/local/bin/codex-warmup` |
| Afternoon warmup     | `14 15 * * *` | `Africa/Harare` | `/usr/local/bin/codex-warmup` |

If your scheduler does not support timezones and runs in UTC, use:

| Harare time |      UTC cron |
| ----------: | ------------: |
|       05:00 |   `0 3 * * *` |
|       10:07 |   `7 8 * * *` |
|       15:14 | `14 13 * * *` |

---

## Troubleshooting

### `OPENCODE_AUTH_JSON env var is missing`

The variable is not available inside the running container.

Fix:

1. Add `OPENCODE_AUTH_JSON` to the application’s runtime environment.
2. Redeploy the app.
3. Check inside the container:

```bash
echo "$OPENCODE_AUTH_JSON" | head -c 20
```

Expected output starts with:

```text
{"...
```

---

### Email did not arrive

Check:

1. Spam folder.
2. Resend API response in container logs.
3. `RESEND_API_KEY` is set.
4. `NOTIFY_EMAIL` is correct.
5. `FROM_EMAIL_ADDRESS` uses a verified Resend domain.

Run:

```bash
echo "$RESEND_API_KEY" | head -c 8
echo "$NOTIFY_EMAIL"
echo "$FROM_NAME"
echo "$FROM_EMAIL_ADDRESS"
```

---

### Gmail shows sender as lowercase `codexwarmup`

Use sender display variables:

```env
FROM_NAME=Codex Warmup
FROM_EMAIL_ADDRESS=codexwarmup@iamt12e.co.zw
```

The script sends using:

```text
Codex Warmup <codexwarmup@iamt12e.co.zw>
```

---

### Docker cannot find `codex-warmup:test`

You probably built with one Docker context and ran with another, or mixed `docker` and `sudo docker`.

Check:

```bash
docker images | grep codex-warmup
```

Use the same command style for both build and run.

---

### Permission denied when mounting the script

Run the mounted script through Bash:

```bash
docker run --rm -it \
  --env-file .env.local \
  -v "$PWD/codex-warmup.sh:/usr/local/bin/codex-warmup:ro" \
  codex-warmup:test \
  bash -lc "bash /usr/local/bin/codex-warmup"
```

Or make it executable locally:

```bash
chmod +x codex-warmup.sh
```

---

## Build cache tips

For local testing, avoid rebuilding for script-only edits. Use the bind-mount command above.

When rebuilding, avoid pulling newer base images on mobile data:

```bash
docker build --pull=false -t codex-warmup:test .
```

Add a `.dockerignore`:

```dockerignore
.git
.env
.env.local
node_modules
README.md
```

---

## Security notes

* Do not commit `.env`, `.env.local`, or any auth JSON.
* Do not print the full `OPENCODE_AUTH_JSON` in logs.
* Keep the Dokploy app private; it does not need a public domain.
* Rotate Codex auth if the token is leaked.
* Treat Resend API keys as secrets.
