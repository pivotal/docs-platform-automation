# blackduck-scan

Black Duck Detect SIGNATURE_SCAN stage that runs after `submit-release-sboms-*`
in the `minor-bump` and `patch-bump` pipeline groups, before `publish-release-*`.

## Files

- [`blackduck-scan.yml`](./blackduck-scan.yml) - Concourse task definition (uses the `ci-image`).
- [`blackduck-scan.sh`](./blackduck-scan.sh) - Extracts the packaged release artifact and invokes `detect.sh` with SIGNATURE_SCAN + snippet matching + source upload.
- [`blackduck-carry-forward-justifications.yml`](./blackduck-carry-forward-justifications.yml) - Concourse task that copies a BOM component's `usages` array (e.g. `["MERELY_AGGREGATED"]`) from the previous release version onto the current one.
- [`blackduck-carry-forward-justifications.sh`](./blackduck-carry-forward-justifications.sh) - Standalone script the task runs; can also be run locally with the same env vars (`--help` for full options).

## Image dependencies (already baked into [`ci/dockerfiles/Dockerfile.ci`](../dockerfiles/Dockerfile.ci))

- `openjdk-17-jre-headless` (Detect 9.x requires Java 17+)
- `/usr/local/bin/detect.sh` (the launcher)
- `/opt/blackduck/detect/detect.jar` pinned to `${DETECT_VERSION}` (currently `9.10.0`)

To pin a different Detect version, change `DETECT_VERSION` in `Dockerfile.ci` and
rebuild `ci-image` via the `build-ci-image` job.

## Required Concourse credentials

Three secrets must exist in the credential manager before the pipeline can be
set with `fly set-pipeline`. The pipeline reads them via `((...))` interpolation
following the existing `platform-automation/main/...` convention used elsewhere
in [`ci/ci/pipeline.yml`](../ci/pipeline.yml).

| Concourse var path                                | Purpose                                        |
| ------------------------------------------------- | ---------------------------------------------- |
| `platform-automation/main/blackduck.url`          | Black Duck server URL (e.g. `https://broadcom-vmw.app.blackduck.com`) |
| `platform-automation/main/blackduck.api_token`    | Black Duck API token (rotate via Black Duck UI; treat as secret) |
| `platform-automation/main/blackduck.project_name` | Detect project name (e.g. `TNZ-CF-platform-automation`) |

These map to the task params:

```yaml
BLACKDUCK_URL: ((platform-automation/main/blackduck.url))
BLACKDUCK_API_TOKEN: ((platform-automation/main/blackduck.api_token))
BLACKDUCK_PROJECT_NAME: ((platform-automation/main/blackduck.project_name))
```

The Detect project version is set automatically from the `version` resource
(`version-v5.x` for `minor-bump`, `version-v{number}` for `patch-bump`) so each
release line gets its own Black Duck project version.

## Pipeline flow

```text
bump-minor       --> submit-release-sboms-v5.x   --> blackduck-scan-v5.x      --> publish-release-minor
update-v{ver}    --> submit-release-sboms-v{ver} --> blackduck-scan-v{ver}    --> publish-release-v{ver}
```

`publish-release-*` is gated on a green `blackduck-scan-*` (it does NOT
depend on `submit-release-sboms-*` directly any more). If you need to skip the
scan for an emergency release, manually re-trigger `publish-release-*` with the
required input from the upstream artifact resource.

## Carry-forward of usages / justifications (`blackduck-carry-forward-justifications.*`)

In Black Duck the structured "Usage" of a BOM component (`DYNAMICALLY_LINKED`,
`STATICALLY_LINKED`, `MERELY_AGGREGATED`, `IMPLEMENTATION_OF_STANDARD`,
`PREREQUISITE`, `SOURCE_CODE`, `SEPARATE_WORK`, `DEV_TOOL_EXCLUDED`) is the
field that license policies actually evaluate. When you create a new project
version, components there inherit BD's default usage and lose the human review
decision (e.g. `MERELY_AGGREGATED`) made on the previous release.

[`blackduck-carry-forward-justifications.sh`](./blackduck-carry-forward-justifications.sh)
copies that `usages` array forward for components that exist in both versions,
without auto-suppressing genuinely new findings.

Important: this script does NOT change the `ignored` flag, does NOT write the
free-text `comment`, and does NOT touch components that are absent from the
previous version. Any component missing from the previous release is logged as
a SKIP and left for human review.

What it does:

1. Authenticates with the API token, exchanging it for a short-lived bearer.
2. Looks up the BD project, the current version, and the previous version.
3. Lists the current version's components with the server-side filter
   `?filter=policyCategory:LICENSE` (configurable via
   `BLACKDUCK_POLICY_CATEGORY`), so only LICENSE-violating components are
   considered.
4. For each component that is also `policyStatus == IN_VIOLATION` and not
   `ignored`, it issues **one** targeted call against the previous version,
   `GET <PREV>/components?q=componentOrVersionName:<name>&limit=50`, and picks
   the matching prior entry (exact `(name, version)` by default; name-only
   fallback if `BLACKDUCK_MATCH_MODE=name`).
5. If the matching prior entry has a non-empty `usages` array that differs
   from the current `usages`, the script `PUT`s
   `{"usages": [...prev usages...]}` to the current component's BOM URL.
   Otherwise it logs `SAME` (no change needed) or `SKIP` (not present in prev,
   or prev had empty `usages`).

Required env vars (also exposed as Concourse params on
[`blackduck-carry-forward-justifications.yml`](./blackduck-carry-forward-justifications.yml)):

| Name | Purpose |
| ---- | ------- |
| `BLACKDUCK_URL` | BD server URL (e.g. `https://broadcom-vmw.app.blackduck.com`). Same secret as the scan task. |
| `BLACKDUCK_API_TOKEN` | BD API token. Same secret as the scan task. |
| `BLACKDUCK_PROJECT_NAME` | BD project name (e.g. `TNZ-CF-platform-automation`). Same secret as the scan task. |
| `BLACKDUCK_VERSION` | Current BD project version (e.g. `5.5.1`). |
| `BLACKDUCK_PREVIOUS_VERSION` | Previous BD project version (e.g. `5.5.0`). |

Optional env vars:

| Name | Default | Purpose |
| ---- | ------- | ------- |
| `BLACKDUCK_POLICY_CATEGORY` | `LICENSE` | Which violating-policy category to act on. Other values: `SECURITY`, `OPERATIONAL`, `COMPONENT`, `VERSION`. |
| `BLACKDUCK_MATCH_MODE` | `name-version` | `name-version` (exact match) or `name` (also accept name-only fallback when patch-level versions drift). |
| `DRY_RUN` | `false` | When `true`, prints what would be carried forward without calling the BD API. |

Local dry-run example:

```bash
export BLACKDUCK_URL='https://broadcom-vmw.app.blackduck.com'
export BLACKDUCK_API_TOKEN='...'
export BLACKDUCK_PROJECT_NAME='TNZ-CF-platform-automation'
export BLACKDUCK_VERSION='5.5.1'
export BLACKDUCK_PREVIOUS_VERSION='5.5.0'
export DRY_RUN=true
./ci/tasks/blackduck-carry-forward-justifications.sh
```

Wiring into the pipeline (sketch — not yet added to `ci/ci/pipeline.yml`):
add a `blackduck-carry-forward-justifications-{version}` job that runs after
`blackduck-scan-{version}` and before `publish-release-{version}`. Use
`load_var` from the version resource to populate `BLACKDUCK_VERSION` and a
manually-curated `BLACKDUCK_PREVIOUS_VERSION` (or compute it from the same
resource using a `prev: 1` semver get if you prefer fully automatic chaining).
