#!/usr/bin/env bash
# blackduck-carry-forward-justifications.sh
#
# Carry forward the BOM-component `usages` field (e.g.
# ["MERELY_AGGREGATED"]) from the PREVIOUS Black Duck project version onto the
# CURRENT version, when the same component is present in both.
#
# In Black Duck, the structured "Usage" of a component (DYNAMICALLY_LINKED,
# STATICALLY_LINKED, MERELY_AGGREGATED, IMPLEMENTATION_OF_STANDARD,
# PREREQUISITE, SOURCE_CODE, SEPARATE_WORK, DEV_TOOL_EXCLUDED) is what license
# policies evaluate against. Carrying it forward preserves the human review
# decision made on the previous release without auto-suppressing findings.
#
# This script does NOT change the `ignored` flag, does NOT touch the free-text
# `comment`, and does NOT affect components that are new in the current
# version (they surface for fresh review).
#
# Behaviour:
#   For each BOM component in the CURRENT version that
#     - has policyStatus == IN_VIOLATION,
#     - has at least one violating policy of category BLACKDUCK_POLICY_CATEGORY
#       (default LICENSE), and
#     - is NOT ignored,
#   look the same component up in the PREVIOUS version with a single targeted
#   GET (filtered by component name). If it is present and its `usages` array
#   is non-empty AND different from the current `usages`, PUT
#   {"usages": [...prev usages...]} onto the current component. Otherwise, log
#   a SKIP / SAME line and leave it alone.
#
# Required env vars:
#   BLACKDUCK_URL                  e.g. https://broadcom-vmw.app.blackduck.com
#   BLACKDUCK_API_TOKEN            API token (used to obtain a bearer token)
#   BLACKDUCK_PROJECT_NAME         e.g. TNZ-CF-platform-automation
#   BLACKDUCK_VERSION              current project version (e.g. 5.5.1)
#   BLACKDUCK_PREVIOUS_VERSION     previous project version (e.g. 5.5.0)
#
# Optional env vars:
#   BLACKDUCK_POLICY_CATEGORY      default: LICENSE
#                                  (LICENSE | SECURITY | OPERATIONAL |
#                                   COMPONENT | VERSION) - applied as a
#                                  server-side `?filter=policyCategory:...`
#                                  on the current version's components.
#   BLACKDUCK_MATCH_MODE           default: name-version
#                                    "name-version" : exact componentName +
#                                                     componentVersionName
#                                    "name"         : also accept name-only
#                                                     fallback when patch
#                                                     versions drift
#   DRY_RUN                        default: false; print intended PUTs only
#
# Tools required: curl, jq
#
set -euo pipefail

usage() {
  cat <<'EOF'
blackduck-carry-forward-justifications.sh — copy a BOM component's `usages`
field (e.g. ["MERELY_AGGREGATED"]) from the previous Black Duck project version
onto the current one when the same component is present in both. Preserves
license-review decisions without auto-suppressing genuinely new findings.

What it touches:
  - WRITES the `usages` array on the current BOM component via PUT.
  - DOES NOT change `ignored`, `comment`, `reviewStatus`, or any other field.
  - SKIPS components that are not present (or have empty `usages`) in the
    previous version - those are left for a human to review.

Usage:
  blackduck-carry-forward-justifications.sh [--help|-h] [--dry-run]

Configuration is read from environment variables (no positional args):

  Required:
    BLACKDUCK_URL                Black Duck server URL
                                 (e.g. https://broadcom-vmw.app.blackduck.com)
    BLACKDUCK_API_TOKEN          BD API token used to obtain a bearer token
    BLACKDUCK_PROJECT_NAME       BD project name (e.g. TNZ-CF-platform-automation)
    BLACKDUCK_VERSION            Current project version  (e.g. 5.5.1)
    BLACKDUCK_PREVIOUS_VERSION   Previous project version (e.g. 5.5.0)

  Optional:
    BLACKDUCK_POLICY_CATEGORY    default: LICENSE
                                 (LICENSE | SECURITY | OPERATIONAL |
                                  COMPONENT | VERSION)
                                 Applied as a server-side filter on the
                                 current version's /components endpoint.
    BLACKDUCK_MATCH_MODE         default: name-version
                                 (name-version | name) — name-only is a
                                 fallback for when patch-level versions drift.
    DRY_RUN                      default: false  (also settable with --dry-run)

Per-component log lines:
    + APPLY  <name>@<curVer>  <-  prev <name>@<prevVer>  usages: [MERELY_AGGREGATED]
    + DRYRUN <name>@<curVer>  <-  prev <name>@<prevVer>  usages: [DYNAMICALLY_LINKED, MERELY_AGGREGATED]
    = SAME   <name>@<curVer>: usages already match prev <name>@<prevVer> ([...]) — no PUT needed
    - SKIP   <name>@<curVer>: not present in <prevVer>  (no carry-forward; leave for review)
    - SKIP   <name>@<curVer>: matched prev <name>@<prevVer> but it has no `usages` set

Examples:
  BLACKDUCK_URL=https://broadcom-vmw.app.blackduck.com \
  BLACKDUCK_API_TOKEN=*** \
  BLACKDUCK_PROJECT_NAME=TNZ-CF-platform-automation \
  BLACKDUCK_VERSION=5.5.1 BLACKDUCK_PREVIOUS_VERSION=5.5.0 \
    ./blackduck-carry-forward-justifications.sh

  DRY_RUN=true ./blackduck-carry-forward-justifications.sh
  ./blackduck-carry-forward-justifications.sh --dry-run

Exit codes:
  0  success (or nothing to carry forward)
  1  authentication / project / version-resolution error
  2  one or more PUT calls failed (each is logged with its component + URL)

A component that is missing from the previous version is NOT an error: the
script logs a SKIP line for that component and continues.
EOF
}

# Parse simple flags before any env-var validation so --help works without
# requiring credentials. Unknown flags fall through to the validators below.
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      echo "Unexpected positional argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

: "${BLACKDUCK_URL:?BLACKDUCK_URL is required (run with --help for usage)}"
: "${BLACKDUCK_API_TOKEN:?BLACKDUCK_API_TOKEN is required (run with --help for usage)}"
: "${BLACKDUCK_PROJECT_NAME:?BLACKDUCK_PROJECT_NAME is required (run with --help for usage)}"
: "${BLACKDUCK_VERSION:?BLACKDUCK_VERSION is required (run with --help for usage)}"
: "${BLACKDUCK_PREVIOUS_VERSION:?BLACKDUCK_PREVIOUS_VERSION is required (run with --help for usage)}"

POLICY_CATEGORY="${BLACKDUCK_POLICY_CATEGORY:-LICENSE}"
MATCH_MODE="${BLACKDUCK_MATCH_MODE:-name-version}"
DRY_RUN="${DRY_RUN:-false}"

BD="${BLACKDUCK_URL%/}"
# Reads use plain application/json — every BD endpoint accepts it and returns
# the latest representation, which avoids HTTP 406 when the strict project /
# project-version media types do not match the bill-of-materials media type.
JSON_MEDIA="application/json"
BOM_MEDIA="application/vnd.blackducksoftware.bill-of-materials-6+json"
USER_MEDIA="application/vnd.blackducksoftware.user-4+json"

log() { printf '%s\n' "$*" >&2; }

# 1. Authenticate -> bearer token
log "Authenticating to ${BD} ..."
BEARER="$(curl -fsSL -X POST \
  -H "Authorization: token ${BLACKDUCK_API_TOKEN}" \
  -H "Accept: ${USER_MEDIA}" \
  "${BD}/api/tokens/authenticate" \
  | jq -r '.bearerToken')"

if [[ -z "$BEARER" || "$BEARER" == "null" ]]; then
  log "ERROR: failed to obtain bearer token from Black Duck."
  exit 1
fi

bd_get() {
  # Generic JSON GET that works for /api/projects, /api/projects/{id}/versions,
  # /api/projects/{id}/versions/{vid}/components, and policy-rules subresources.
  # Using Accept: application/json keeps us out of the strict-media-type 406
  # trap when an endpoint does not declare the bill-of-materials media type.
  curl -fsSL -X GET \
    -H "Authorization: Bearer ${BEARER}" \
    -H "Accept: ${JSON_MEDIA}" \
    "$1"
}

bd_get_soft() {
  # Like bd_get but never aborts the script: any non-2xx, network failure, or
  # empty body returns an empty string and exit code 0. Used for previous-
  # version cross-checks where "not found" is a normal outcome that must NOT
  # error the whole run.
  local url="$1" out
  if out="$(curl -sSL -X GET \
        -H "Authorization: Bearer ${BEARER}" \
        -H "Accept: ${JSON_MEDIA}" \
        --fail-with-body \
        "$url" 2>/dev/null)"; then
    printf '%s' "$out"
  else
    printf ''
  fi
  return 0
}

bd_put_usages() {
  # PUT only the usages field; BD treats this as a partial update on the BOM
  # component. We deliberately do NOT touch the `ignored` flag or `comment`
  # here. The body must look like {"usages": ["MERELY_AGGREGATED", ...]}.
  local href="$1" body="$2"
  curl -fsSL -X PUT \
    -H "Authorization: Bearer ${BEARER}" \
    -H "Content-Type: ${BOM_MEDIA}" \
    -H "Accept: ${BOM_MEDIA}" \
    -d "$body" \
    "$href" >/dev/null
}

# 2. Find project URL by exact name match
log "Looking up project: ${BLACKDUCK_PROJECT_NAME}"
PROJECT_URL="$(bd_get "${BD}/api/projects?q=name:$(jq -rn --arg v "$BLACKDUCK_PROJECT_NAME" '$v|@uri')&limit=20" \
  | jq -r --arg n "$BLACKDUCK_PROJECT_NAME" '.items[]? | select(.name == $n) | ._meta.href' \
  | head -n1)"

if [[ -z "$PROJECT_URL" ]]; then
  log "ERROR: project not found: ${BLACKDUCK_PROJECT_NAME}"
  exit 1
fi
log "  -> ${PROJECT_URL}"

# 3. Resolve current + previous version URLs
find_version_url() {
  local v="$1"
  bd_get "${PROJECT_URL}/versions?q=versionName:$(jq -rn --arg v "$v" '$v|@uri')&limit=50" \
    | jq -r --arg v "$v" '.items[]? | select(.versionName == $v) | ._meta.href' \
    | head -n1
}

CUR_URL="$(find_version_url "$BLACKDUCK_VERSION")"
PREV_URL="$(find_version_url "$BLACKDUCK_PREVIOUS_VERSION")"

if [[ -z "$CUR_URL" ]]; then
  log "ERROR: current version not found in BD project: ${BLACKDUCK_VERSION}"
  exit 1
fi
if [[ -z "$PREV_URL" ]]; then
  log "ERROR: previous version not found in BD project: ${BLACKDUCK_PREVIOUS_VERSION}"
  exit 1
fi
log "  current  version URL: ${CUR_URL}"
log "  previous version URL: ${PREV_URL}"

urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

# Helper: stream BOM components from a version, server-side filtered by the
# given policyCategory (default LICENSE). Yields one JSON object per line.
stream_violating_current_components() {
  local base="$1" category="$2" offset=0 limit=100 page items_count total
  local cat_q
  cat_q="$(urlencode "$category")"
  while :; do
    page="$(bd_get "${base}/components?filter=policyCategory:${cat_q}&limit=${limit}&offset=${offset}")"
    items_count="$(echo "$page" | jq '.items | length')"
    [[ "$items_count" -eq 0 ]] && break
    echo "$page" | jq -c '.items[]'
    total="$(echo "$page" | jq '.totalCount')"
    offset=$((offset + items_count))
    [[ "$offset" -ge "$total" ]] && break
  done
}

# 4. Iterate ONLY the CURRENT version's components that are in violation under
#    the chosen policy category, and that are NOT ignored. For each such
#    candidate, do ONE targeted GET against the PREVIOUS version's components
#    (filtered by component name) to find the matching prior entry, and copy
#    its `usages` (e.g. ["MERELY_AGGREGATED"]) forward.
log "Scanning current version ${BLACKDUCK_VERSION} for category=${POLICY_CATEGORY} not-ignored violations ..."

applied=0
candidates=0
no_prev_match=0
no_prev_usages=0
already_same=0
ignored_skipped=0
not_in_violation=0
errors=0

while IFS= read -r row; do
  ignored="$(echo "$row" | jq -r '.ignored // false')"
  policy_status="$(echo "$row" | jq -r '.policyStatus // empty')"
  name="$(echo "$row" | jq -r '.componentName // empty')"
  ver="$(echo "$row" | jq -r '.componentVersionName // empty')"
  href="$(echo "$row" | jq -r '._meta.href // empty')"
  curr_usages_json="$(echo "$row" | jq -c '(.usages // []) | sort')"

  [[ -z "$href" || -z "$name" ]] && continue

  # Defensive: server-side filter should already narrow these, but BD versions
  # vary, so we re-check client-side.
  if [[ "$ignored" == "true" ]]; then
    ignored_skipped=$((ignored_skipped + 1))
    continue
  fi
  if [[ "$policy_status" != "IN_VIOLATION" ]]; then
    not_in_violation=$((not_in_violation + 1))
    continue
  fi

  candidates=$((candidates + 1))

  # ONE targeted call into the previous version, scoped by component name.
  # BD's `q=componentOrVersionName:<term>` does fuzzy matching; we filter the
  # response in jq for an exact name (and prefer same versionName) match.
  # bd_get_soft never aborts the script, so a missing component or transient
  # BD error is treated as "not present in previous version" -> skip.
  encoded_name="$(urlencode "$name")"
  prev_resp="$(bd_get_soft "${PREV_URL}/components?q=componentOrVersionName:${encoded_name}&limit=50")"

  prev_match=""
  if [[ -n "$prev_resp" ]]; then
    prev_match="$(printf '%s' "$prev_resp" | jq -c \
      --arg n    "$name" \
      --arg v    "$ver" \
      --arg mode "$MATCH_MODE" '
      [.items[]? | select(.componentName == $n)] as $by_name
      | if ($by_name | length) == 0 then empty
        else
          ($by_name | map(select(.componentVersionName == $v)) | .[0]) as $exact
          | if $exact != null then $exact
            elif $mode == "name" then $by_name[0]
            else empty
            end
        end
    ' 2>/dev/null || true)"
  fi

  if [[ -z "$prev_match" || "$prev_match" == "null" ]]; then
    log "  - SKIP  ${name}@${ver}: not present in ${BLACKDUCK_PREVIOUS_VERSION} (no carry-forward; leave for review)"
    no_prev_match=$((no_prev_match + 1))
    continue
  fi

  prev_ver="$(echo "$prev_match"        | jq -r '.componentVersionName // empty')"
  prev_usages_json="$(echo "$prev_match" | jq -c '(.usages // []) | sort')"
  prev_usages_human="$(echo "$prev_match" | jq -r '(.usages // []) | join(", ")')"

  if [[ "$prev_usages_json" == "[]" ]]; then
    log "  - SKIP  ${name}@${ver}: matched prev ${name}@${prev_ver} but its usages array is empty (left for review)"
    no_prev_usages=$((no_prev_usages + 1))
    continue
  fi

  if [[ "$prev_usages_json" == "$curr_usages_json" ]]; then
    log "  = SAME  ${name}@${ver}: usages already match prev ${name}@${prev_ver} ([${prev_usages_human}]) — no PUT needed"
    already_same=$((already_same + 1))
    continue
  fi

  # Body is the prev usages array, sorted to make logs deterministic.
  body="$(printf '%s' "$prev_usages_json" | jq -c '{usages: .}')"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "  + DRYRUN ${name}@${ver}  <-  prev ${name}@${prev_ver}  usages: [${prev_usages_human}]"
    applied=$((applied + 1))
  else
    log "  + APPLY  ${name}@${ver}  <-  prev ${name}@${prev_ver}  usages: [${prev_usages_human}]"
    if bd_put_usages "$href" "$body"; then
      applied=$((applied + 1))
    else
      log "    WARN: PUT ${href} failed"
      errors=$((errors + 1))
    fi
  fi
done < <(stream_violating_current_components "$CUR_URL" "$POLICY_CATEGORY")

log ""
log "Summary (${BLACKDUCK_PROJECT_NAME} ${BLACKDUCK_PREVIOUS_VERSION} -> ${BLACKDUCK_VERSION}, category=${POLICY_CATEGORY}):"
log "  candidates considered          : ${candidates}"
log "  usages carried forward         : ${applied}"
log "  no match in previous version   : ${no_prev_match}"
log "  prev had empty usages          : ${no_prev_usages}"
log "  usages already match prev      : ${already_same}"
log "  already ignored, skipped       : ${ignored_skipped}"
log "  not actually in violation      : ${not_in_violation}"
log "  PUT errors                     : ${errors}"

if [[ "$errors" -gt 0 ]]; then
  exit 2
fi
