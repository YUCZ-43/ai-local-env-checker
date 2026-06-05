# CLI Plan

The future CLI executable is `ai-local-deploy`.

## MVP commands

- `ai-local-deploy check`
- `ai-local-deploy doctor`
- `ai-local-deploy report`
- `ai-local-deploy plan`

## Future commands

- `ai-local-deploy check --json`
- `ai-local-deploy plan --target claude-code`
- `ai-local-deploy apply --plan plan.json`
- `ai-local-deploy report --open`
- `ai-local-deploy logs`

## Safety

`apply` must not exist until policy, confirmation, logging, rollback metadata, and verification are implemented. The default path remains check-only.
