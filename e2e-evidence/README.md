# e2e-evidence/

This directory holds **real-system validation artifacts** for Burrow.

## Iron rules (PRP §6)

1. No mocks, no test files, no fixtures.
2. No XCTest target.
3. Every PASS verdict cites a specific file under this tree.
4. Empty files (0 bytes) are invalid evidence.
5. Compilation is necessary but not sufficient for a phase to be marked complete.

## Layout

```
e2e-evidence/
├── README.md                this file
├── inventory.txt            byte-count + capture-time index
├── phase-00/ ... phase-09/  per-phase artifacts
└── AT-1/ ... AT-10/         per-acceptance-test artifacts (PRD §11.1)
```

Each phase directory holds the artifact named in `PHASES.md`. Each AT directory holds:

- `description.md` — scenario, steps, expected vs observed
- `artifact.{png,mov,log,json}` — captured during execution
- `verdict.md` — PASS / FAIL with cited artifact paths

## What counts as valid evidence

| Artifact type | Acceptable formats | What makes it invalid |
|---------------|--------------------|------------------------|
| Screenshot | `.png`, `.jpg` | Empty file, blank UI, missing the relevant content |
| Screen recording | `.mov`, `.mp4` | < 5 s duration, no audio commentary needed but content must be visible |
| API response | `.json` | Hand-crafted, modified, or scrubbed of fields |
| Shell session | `.log`, `.txt` | Edited, summarized, or omitting timestamps |
| Compiled binary verification | `.json` (notarization receipt) | Missing the request UUID or status |

## Adding evidence

```bash
# Capture a screenshot of the menu bar app
screencapture -i e2e-evidence/phase-01/menubar-screenshot.png

# Capture a real CF API response
curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify \
  > e2e-evidence/phase-00/token-verify.json

# Capture an OSLog excerpt
log show --predicate 'subsystem == "com.krzemienski.burrow"' --last 1h \
  > e2e-evidence/phase-04/oslog-excerpt.log
```

After capture, update `inventory.txt` with the byte count and ISO-8601 timestamp.
