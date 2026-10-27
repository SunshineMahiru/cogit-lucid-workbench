# Local mock server

Zero-dependency Node server used by the review prompt panel.

## Run

```bash
node mock-server/server.js
```

The server listens on `0.0.0.0:4523` by default; override with `PORT`.

## Endpoints

| Method | Path | Response |
|---|---|---|
| GET | `/health` | `{ "status": "ok" }` |
| GET | `/review-prompts?period=week` | `{ "prompts": [...] }` |
| GET | `/review-prompts?period=month` | `{ "prompts": [...] }` |
| POST | `/llm/complete` | `{ "model": "mock-local", "content": "{\"candidates\":[...]}" }` |
| POST | `/v1/chat/completions` | OpenAI-compatible `choices[0].message.content` |

## Addressing

- DevEco Previewer: `http://127.0.0.1:4523` works as-is.
- Emulator: `127.0.0.1` points at the emulator itself. Change `API_BASE_URL`
  in `entry/src/main/ets/network/ApiConfig.ts` to the host LAN IP.
- All prompt text is synthetic; no user data is sent or logged.
