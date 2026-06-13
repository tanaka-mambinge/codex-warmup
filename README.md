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
