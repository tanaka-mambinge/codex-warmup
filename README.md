# codex-warmup

A tiny container that runs a single `codex exec` "warmup" call so that Codex auth/session state is exercised on a schedule (or on demand).

The script spins up a throwaway `$HOME` and workdir, writes your Codex credentials and a minimal `config.toml`, runs one prompt, then cleans everything up.

## Configuration

The container needs your Codex credentials provided via the **`CODEX_AUTH_JSON`** environment variable. Its value is the contents of your local `~/.codex/auth.json` as a single compact line.

Generate the value with:

```bash
jq -c . ~/.codex/auth.json
```

Copy the output and set it as the `CODEX_AUTH_JSON` environment variable wherever you deploy (CI secret, container env var, scheduler secret, etc.).

> ⚠️ Treat this value as a secret — it contains your Codex auth tokens. Store it in a secrets manager, never commit it.

## Run

Build:

```bash
docker build -t codex-warmup .
```

Run the warmup:

```bash
docker run --rm -e CODEX_AUTH_JSON="$(jq -c . ~/.codex/auth.json)" codex-warmup codex-warmup
```

The default `CMD` keeps the container alive (`tail -f /dev/null`); invoke the `codex-warmup` script explicitly (as above) or on your own schedule.

## Manual trigger

If the container is already running (e.g. via the default `CMD`), you can manually trigger a warmup run by exec-ing into it:

```bash
docker exec -it <container> /usr/local/bin/codex-warmup
```

## Schedules

This container does not schedule anything itself — set up a cron schedule (or your platform's scheduler) on the server to run `/usr/local/bin/codex-warmup` inside the container at the times you want.

### Example schedule

Your container is using UTC, so use these for Harare/Zimbabwe time:

| Harare time | UTC cron      | Command                       |
|-------------|---------------|--------------------------------|
| 05:00       | `0 3 * * *`   | `/usr/local/bin/codex-warmup` |
| 10:07       | `7 8 * * *`   | `/usr/local/bin/codex-warmup` |
| 15:14       | `14 13 * * *` | `/usr/local/bin/codex-warmup` |
