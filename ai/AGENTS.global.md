# Global agent instructions (Brennan)

## Operating mode
- Be decisive and practical. Default to minimal diffs and fast feedback loops.
- If requirements are ambiguous, propose the smallest sensible plan and execute.
- Prefer edits that keep the codebase consistent with existing patterns.

## Safety / guardrails
- Never exfiltrate secrets. Treat .env, credentials, tokens, private keys as sensitive.
- Don’t add telemetry, tracking, or new external services without asking first.
- Don’t run destructive commands (rm -rf, git reset --hard, dropping DBs) without explicit confirmation.
- When in doubt about security-sensitive changes (auth, payments, crypto, access control), stop and ask.

## Workflow expectations
- Always explain what you changed and why.
- After code changes, run the most relevant checks:
  - JS/TS: lint + tests (and typecheck if present)
  - Ruby: bundle exec rspec (or the project test command), rubocop if present
- If you can’t run commands, say so and provide exact commands for me to run.

## JavaScript / TypeScript conventions
- Prefer modern JS/TS patterns and readability.
- Don’t introduce new dependencies unless necessary—ask first for production deps.
- Prefer small, composable functions; avoid clever abstractions.
- Write tests for behavior changes.

## Ruby conventions
- Prefer clear, idiomatic Ruby.
- Keep Rails code consistent with the project (service objects, concerns, etc).
- Avoid metaprogramming unless the codebase already leans on it.
- Add/adjust specs for behavior changes.

## Git hygiene
- Keep commits scoped and message clearly.
- Confirm scope before committing: check `git status -sb` and `git diff`.
- Prefer `git add -p` and small, reviewable commits.
- Don’t push, force-push, or merge PRs without explicit confirmation.
- If a force push is truly required, use `--force-with-lease` and explain why.
- Prefer feature branches + PRs; don’t commit directly to the default branch unless asked.
- Prefer `gh` for GitHub operations (PRs, checks, releases) and confirm before creating/updating PRs.
- Don’t change formatting across unrelated files.
- If you touch config/tooling, explain the impact and how to revert.

## “Ask before doing”
- Adding production dependencies
- Changing CI/build pipelines
- Changing DB schemas/migrations
- Anything that might break backward compatibility
