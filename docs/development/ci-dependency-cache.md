# Application CI dependency cache

The `application-cache.yml` workflow builds dependency files on pushes to `main`.
Pull requests restore the same exact key but never save this cache. The key binds
the runner image and architecture, test environment, toolchain, lockfile, Mix
project and configuration. The cache contains dependency files only, never test
results or the application build. Foundation Integrity remains PR-only and the
nightly hardening job remains cold.

Before writing the manifest, the [trusted writer](../../tools/ci/cache_manifest.py)
removes group and other write
permission from regular cached files. This preserves owner permissions and
executable bits, avoids following symbolic links, and makes those modes stable
when GNU tar extracts the archive with the hosted runner's `0022` umask. The
manifest still records and checks each file's exact mode and content hash and
each symlink target. A subsequent mode change is rejected. A more restrictive
extraction umask can still cause a safe rebuild.

## WELL-105 reproduction

PR #213 run `42783058564` restored the v1 trusted-main cache, then rejected its
manifest. Diagnostic PR runs `42789191668` and `42789696774` restored that same
exact key and reported 343 mode-only mismatches in `deps`. The second run showed
`0664` to `0644` for each of the first ten examples. A separate local GNU tar
round trip of a dependency tree under umask `0022` reproduced 343 mode changes and the
same first ten path fingerprints. For example, locally matched dependency files
were `0664` before extraction and `0644` afterward. No file contents or cached
paths were emitted by the hosted diagnostics. The draft diagnostic runs were
cancelled after recording the mismatch so their logs could be inspected promptly.
With mode normalization applied, that same local dependency tree passed the
manifest check after a fresh GNU tar round trip under umask `0022`.

Regression tests in [`test_ci_cache_recovery.py`](../../tests/test_ci_cache_recovery.py) exercise tar extraction,
group-writable and executable files, symlinks, a payload inconsistent with its
manifest, a truncated archive, non-exact keys, restore failure and clean retry.
This CI-only change has no application or Domain interface handoff; this note records its proof and
limits. A v2 cache must still be produced on trusted main and successfully
validated by a later real PR before warm reuse or a speedup can be claimed.

The cache is optional. A missing, partial or failed restore, a mismatched integrity
manifest, or failed dependency preparation causes a clean locked fetch and
dependency compilation. The normal CI gates still execute. If a clean attempt
fails, the job fails.

GitHub caches are immutable. A persistently corrupt exact-key cache cannot be
overwritten by the warmer. Until it expires or an operator invalidates it, runs
discard it and rebuild dependencies. To recover reuse without granting the warmer
cache deletion permissions, change the `app-deps-v2` prefix consistently in
both application workflows through a reviewed PR. Verify the new trusted `main`
cache and a later PR hit after that PR is separately authorized and merged.

Cache hits are not test evidence. Compare repeated hosted runs with matching
toolchain, image and scope before claiming a speedup; record cache restore,
compilation, ExUnit and total job times separately.
