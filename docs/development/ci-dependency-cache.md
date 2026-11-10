# Application CI dependency cache

The `application-cache.yml` workflow builds dependency files on pushes to `main`.
Pull requests restore the same exact key but never save this cache. The key binds
the runner image and architecture, test environment, toolchain, lockfile, Mix
project and configuration. The cache contains dependency files only, never test
results or the application build. Foundation Integrity remains PR-only and the
nightly hardening job remains cold.

The cache is optional. A missing or failed restore, a mismatched integrity
manifest, or failed dependency preparation causes a clean locked fetch and
dependency compilation. The normal CI gates still execute. If a clean attempt
fails, the job fails.

GitHub caches are immutable. A persistently corrupt exact-key cache cannot be
overwritten by the warmer. Until it expires or an operator invalidates it, runs
discard it and rebuild dependencies. To recover reuse without granting the warmer
cache deletion permissions, change the `app-deps-v1` prefix consistently in
both application workflows through a reviewed PR. Verify the new trusted `main`
cache and a later PR hit after that PR is separately authorized and merged.

Cache hits are not test evidence. Compare repeated hosted runs with matching
toolchain, image and scope before claiming a speedup; record cache restore,
compilation, ExUnit and total job times separately.
