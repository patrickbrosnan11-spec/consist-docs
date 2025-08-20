# AI Usage Policy

- Default to server‑side LLM calls; never expose secrets to clients.
- Strip names/IDs before sending to models when feasible.
- Constrain outputs to JSON using schemas; retry with error hints if parsing fails.
- Log prompt templates and versions; do not log raw PII.
- Provide opt‑out for all AI features; no features blocked when disabled.
