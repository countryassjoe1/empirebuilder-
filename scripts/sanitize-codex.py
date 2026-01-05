#!/usr/bin/env python3
"""Simple placeholder to sanitize a codex export into a public JSON file."""
import json
import sys

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: sanitize-codex.py <input.json> <output.json>")
        sys.exit(2)
    inp, outp = sys.argv[1], sys.argv[2]
    with open(inp) as f:
        data = json.load(f)
    # Placeholder: remove private fields
    public = []
    for item in data.get('codex', []):
        safe = {k: v for k, v in item.items() if not k.startswith('_')}
        public.append(safe)
    with open(outp, 'w') as f:
        json.dump({'codex': public}, f, indent=2)
    print(f"Wrote sanitized codex to {outp}")
