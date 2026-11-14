# Local DevCore worktree environment

NewYou uses existing shared DEV and TEST PostgreSQL allocations. Each checkout/worktree has its own Git-ignored `.env.dev.local` and `.env.test.local` files. A new worktree may lack those files without any database or credential fault. The T3 Code worktree bootstrap may render them before an agent starts; verify in the actual worktree regardless.

The canonical startup policy is in [AGENTS.md](../AGENTS.md). If doctor passes initially, proceed without render.

From the current worktree root:

1. Run `devcore-project doctor`.
2. If the only failure is a missing or stale local rendered environment file, run `devcore-project render`, then rerun `devcore-project doctor`.
3. If database connectivity, authentication, role/ownership checks, central credentials or shared services fail, report the non-secret error and stop environment preparation. Do not automatically provision or repair shared state.

`devcore-project render` uses the existing central credentials to write ignored local files; it does not provision roles/databases or rotate credentials.

`devcore-project activate` can provision/alter PostgreSQL roles and databases and reapply credential state. It is **not** a routine worktree bootstrap command or a fallback for every `doctor` failure. Use it only for separately authorised workstation provisioning.

Run Elixir and Mix tasks with the pinned Mise runtime and the selected DevCore profile:

- DEV: `mise exec -- devcore-project run dev -- mix <task>`
- TEST: `mise exec -- devcore-project run test -- mix <task>`

Never print or commit credentials or rendered environment files. Do not start, stop, recreate, reset or delete shared DevCore services or databases. Redis is disabled; both PostgreSQL roles must remain `NOCREATEDB`.
