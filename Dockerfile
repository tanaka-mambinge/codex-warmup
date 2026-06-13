FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git bubblewrap \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @openai/codex

WORKDIR /app

COPY codex-warmup.sh /usr/local/bin/codex-warmup
RUN chmod +x /usr/local/bin/codex-warmup

CMD ["tail", "-f", "/dev/null"]