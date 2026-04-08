#!/bin/bash
set -e
cd ~/app
docker compose exec -T api python <<'PY'
import os
from google import genai

k = os.environ.get("GEMINI_API_KEY", "") or ""
print("GEMINI_API_KEY length:", len(k))
if not k:
    raise SystemExit("no key")

c = genai.Client(api_key=k)
for model in ("gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"):
    try:
        r = c.models.generate_content(model=model, contents="Reply with one word: OK")
        t = (r.text or "").strip()
        print(model, "->", repr(t[:120]))
        break
    except Exception as e:
        print(model, "ERR", type(e).__name__, str(e)[:200])
PY
