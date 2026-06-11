#!/usr/bin/env python3
"""
generate-osl-report.py

Triggers the Jenkins "Generate Notices Report" job, waits for it to complete,
downloads the OSL artifact, and saves it with the canonical RMT filename:

  open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_<VERSION>_GA.txt

The output is placed in OUTPUT_DIR (default: generated-osl/) so the calling
Concourse job can `put` it straight to the osl-* S3 resource.

Required environment variables:
  JENKINS_URL              e.g. https://gtso-jenkins.devops.broadcom.net
  JENKINS_USER             Jenkins username
  JENKINS_API_TOKEN        Jenkins API token
  BLACKDUCK_PROJECT_NAME   Black Duck project name (Project_Name parameter)
  JENKINS_OUTPUT_FILE      Jenkins Output_File parameter value  e.g. notices.txt
                           Also used to locate the artifact for download.
  VERSION                  Release version  e.g. 5.5.2

Optional environment variables:
  JENKINS_JOB_PATH         Plain-text job path (default: Black Duck - End User Reports/Generate Notices Report)
  JENKINS_BLACKDUCK_INSTANCE  BlackDuck_Instance parameter value (default: BD-VM)
  OUTPUT_DIR               Output directory (default: generated-osl)
  POLL_INTERVAL_SEC        Seconds between polls (default: 15)
  MAX_WAIT_SEC             Maximum seconds to wait for build completion (default: 3600)
  JENKINS_DEBUG            Set to "true" for verbose request/response logging
"""

import logging
import os
import sys
import time
import urllib.parse

import requests
from requests.auth import HTTPBasicAuth

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

_DEBUG = os.environ.get("JENKINS_DEBUG", "").lower() == "true"


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def get_env(name, default=None, required=True):
    val = os.environ.get(name, default)
    if required and not val:
        logger.error("Required environment variable %s is not set.", name)
        sys.exit(1)
    return val


def build_job_url(jenkins_url, job_path):
    """Return a fully-encoded Jenkins job URL from a plain job path.

    job_path uses '/' to separate folder and job names, e.g.:
      'Black Duck - End User Reports/Generate Notices Report'
    Each segment is percent-encoded individually.
    """
    segments = [urllib.parse.quote(s, safe="") for s in job_path.strip("/").split("/")]
    return f"{jenkins_url.rstrip('/')}/job/{'/job/'.join(segments)}"


# ---------------------------------------------------------------------------
# Pre-flight auth check
# ---------------------------------------------------------------------------

def verify_auth(jenkins_url, auth):
    """Call /me/api/json to confirm credentials are accepted before triggering a build."""
    me_url = f"{jenkins_url}/me/api/json"
    logger.info("Verifying Jenkins credentials via %s ...", me_url)
    try:
        r = requests.get(me_url, auth=auth, timeout=30)
    except Exception as exc:
        logger.error("Auth verification request failed: %s", exc)
        sys.exit(1)

    if r.status_code == 401:
        logger.error(
            "HTTP 401 — credentials rejected. Check JENKINS_USER (%s) and JENKINS_API_TOKEN.",
            auth.username,
        )
        sys.exit(1)

    if r.status_code == 403:
        logger.error(
            "HTTP 403 — user '%s' lacks permission for /me/api/json.", auth.username
        )
        sys.exit(1)

    if r.status_code != 200:
        logger.warning("Auth check returned HTTP %d — proceeding anyway.", r.status_code)
        return

    data = r.json()
    reported_id = data.get("id", "")
    if reported_id == "anonymous":
        logger.error(
            "Jenkins reports user as 'anonymous' — Authorization header may be stripped "
            "by a reverse proxy, or JENKINS_API_TOKEN is wrong.\n"
            "  Supplied user : %s\n"
            "  Regenerate token: Jenkins → user → Configure → API Token",
            auth.username,
        )
        sys.exit(1)

    logger.info("Authenticated as: %s (%s)", reported_id, data.get("fullName", ""))


# ---------------------------------------------------------------------------
# CSRF crumb  — fetched fresh for every request (mirrors reference script)
# ---------------------------------------------------------------------------

def get_crumb(jenkins_url, auth):
    """Return a fresh crumb headers dict {header_name: value}.

    Called inline before every Jenkins API request so each call carries its
    own crumb — this is the pattern used by the working reference script.
    """
    r = requests.get(f"{jenkins_url}/crumbIssuer/api/json", auth=auth, timeout=30)
    if r.status_code == 404:
        logger.debug("Crumb issuer not found — CSRF disabled; proceeding without crumb.")
        return {}
    r.raise_for_status()
    data = r.json()
    crumb_header = data.get("crumbRequestField", "Jenkins-Crumb")
    crumb_value  = data.get("crumb", "")
    if _DEBUG:
        logger.debug("Crumb obtained: %s=%s", crumb_header, crumb_value)
    return {crumb_header: crumb_value}


# ---------------------------------------------------------------------------
# Build trigger
# ---------------------------------------------------------------------------

def trigger_build(jenkins_url, job_path, auth, blackduck_instance,
                  project_name, version, output_file):
    """POST buildWithParameters and return the queue-item API URL."""
    build_params = {
        "BlackDuck_Instance": blackduck_instance,
        "Project_Name":       project_name,
        "Version":            version,
        "Output_File":        output_file,
    }

    trigger_url = f"{build_job_url(jenkins_url, job_path)}/buildWithParameters"
    logger.info("Triggering Jenkins job: %s", trigger_url)
    logger.info("  Parameters: %s", build_params)

    r = requests.post(
        trigger_url,
        params=build_params,
        auth=auth,
        headers=get_crumb(jenkins_url, auth),
        timeout=30,
    )

    if _DEBUG:
        logger.debug("Trigger response: HTTP %d  headers=%s", r.status_code, dict(r.headers))
        if r.text:
            logger.debug("Trigger body (first 500): %s", r.text[:500])

    if r.status_code != 201:
        logger.error(
            "Failed to trigger build: HTTP %d\n"
            "Response headers: %s\nBody (first 500 chars):\n%s",
            r.status_code, dict(r.headers), r.text[:500],
        )
        sys.exit(1)

    # Location header points to the queue item; append api/json to poll it
    queue_url = r.headers["Location"] + "api/json"
    logger.info("Build queued: %s", queue_url)
    return queue_url


# ---------------------------------------------------------------------------
# Queue and build polling
# ---------------------------------------------------------------------------

def wait_for_build_start(queue_url, auth, jenkins_url, poll_interval):
    """Poll the queue item until an executor picks it up; return the build URL."""
    logger.info("Waiting for build to start ...")
    max_queue_wait = 1800
    elapsed = 0
    while elapsed < max_queue_wait:
        time.sleep(poll_interval)
        elapsed += poll_interval
        r = requests.get(queue_url, auth=auth, headers=get_crumb(jenkins_url, auth), timeout=30)
        r.raise_for_status()
        data = r.json()
        if "executable" in data:
            build_number = data["executable"]["number"]
            build_url    = data["executable"]["url"]
            logger.info("Build #%d started: %s", build_number, build_url)
            return build_url
        if data.get("cancelled", False):
            logger.error("Build was cancelled while in queue.")
            sys.exit(1)
        logger.info("  Still queued (%ds elapsed): %s", elapsed, data.get("why", ""))

    logger.error("Timed out after %ds waiting for build to start.", max_queue_wait)
    sys.exit(1)


def wait_for_build_completion(build_url, auth, jenkins_url, poll_interval, max_wait):
    """Poll the build until building=false; return the full build info dict."""
    logger.info("Waiting for build to complete: %s", build_url)
    api_url = f"{build_url}api/json"
    elapsed = 0
    while elapsed < max_wait:
        time.sleep(poll_interval)
        elapsed += poll_interval
        r = requests.get(api_url, auth=auth, headers=get_crumb(jenkins_url, auth), timeout=30)
        r.raise_for_status()
        data = r.json()
        if not data.get("building", True):
            result     = data.get("result", "UNKNOWN")
            duration_s = data.get("duration", 0) / 1000
            logger.info("Build finished: result=%s, duration=%.0fs", result, duration_s)
            if result != "SUCCESS":
                logger.error(
                    "Build did not succeed (result=%s). See %sconsole for details.",
                    result, build_url,
                )
                sys.exit(1)
            return data
        estimated_s = data.get("estimatedDuration", 0) / 1000
        logger.info("  Still building ... elapsed %ds / estimated %.0fs", elapsed, estimated_s)

    logger.error("Timed out after %ds waiting for build to complete.", max_wait)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Artifact download
# ---------------------------------------------------------------------------

def download_osl_artifact(build_info, auth, jenkins_url, version, output_dir, output_file):
    """Download the OSL artifact and save it with the canonical RMT filename.

    Looks for an artifact whose fileName matches output_file.  Falls back to
    any .txt file that looks like a notices/license file.
    """
    artifacts = build_info.get("artifacts", [])
    build_url = build_info.get("url", "")

    if not artifacts:
        logger.error("No artifacts found in build %s", build_url)
        sys.exit(1)

    logger.info("Artifacts in build: %s", [a["fileName"] for a in artifacts])

    # Primary match: fileName == Output_File parameter
    artifact = next((a for a in artifacts if a["fileName"] == output_file), None)

    # Fallback: any OSL-looking .txt file
    if not artifact:
        logger.warning(
            "Artifact '%s' not found by exact name — falling back to OSL keyword search.",
            output_file,
        )
        def _is_osl(a):
            name = a["fileName"].lower()
            return name.endswith(".txt") and any(
                kw in name for kw in ("notice", "license", "osl", "open_source")
            )
        candidates = [a for a in artifacts if _is_osl(a)]
        if not candidates:
            candidates = [a for a in artifacts if a["fileName"].endswith(".txt")] or artifacts
        artifact = candidates[0]
        logger.warning("Using fallback artifact: %s", artifact["fileName"])

    artifact_url = f"{build_url}artifact/{artifact['relativePath']}"
    logger.info("Downloading: %s  <-  %s", artifact["fileName"], artifact_url)

    r = requests.get(
        artifact_url, auth=auth,
        headers=get_crumb(jenkins_url, auth),
        timeout=300, stream=True,
    )
    r.raise_for_status()

    os.makedirs(output_dir, exist_ok=True)
    canonical_name = (
        f"open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu"
        f"_{version}_GA.txt"
    )
    output_path = os.path.join(output_dir, canonical_name)

    with open(output_path, "wb") as fh:
        for chunk in r.iter_content(chunk_size=8192):
            fh.write(chunk)

    size_kb = os.path.getsize(output_path) / 1024
    logger.info("Saved OSL file: %s (%.1f KB)", output_path, size_kb)
    return output_path


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    print("\n" + "=" * 80)
    print(" GENERATE OSL NOTICES REPORT ".center(80, "="))
    print("=" * 80)

    if _DEBUG:
        logging.getLogger().setLevel(logging.DEBUG)
        logger.debug("JENKINS_DEBUG=true — verbose logging enabled")

    jenkins_url        = get_env("JENKINS_URL").rstrip("/")
    jenkins_user       = get_env("JENKINS_USER")
    jenkins_api_token  = get_env("JENKINS_API_TOKEN")
    jenkins_job_path   = get_env(
        "JENKINS_JOB_PATH",
        default="Black Duck - End User Reports/Generate Notices Report",
        required=False,
    )
    blackduck_instance = get_env("JENKINS_BLACKDUCK_INSTANCE", default="BD-VM", required=False)
    output_file        = get_env("JENKINS_OUTPUT_FILE")
    project_name       = get_env("BLACKDUCK_PROJECT_NAME")
    version            = get_env("VERSION")
    output_dir         = get_env("OUTPUT_DIR", default="generated-osl", required=False)
    poll_interval      = int(get_env("POLL_INTERVAL_SEC", default="15", required=False))
    max_wait           = int(get_env("MAX_WAIT_SEC", default="3600", required=False))

    job_url = build_job_url(jenkins_url, jenkins_job_path)
    print(f"Jenkins URL:     {jenkins_url}")
    print(f"Jenkins User:    {jenkins_user}")
    print(f"Jenkins Job:     {job_url}")
    print(f"BD Instance:     {blackduck_instance}")
    print(f"BD Project:      {project_name}")
    print(f"Version:         {version}")
    print(f"Output_File:     {output_file}")
    print(f"Output Dir:      {output_dir}")
    print(f"Poll interval:   {poll_interval}s  |  Max wait: {max_wait}s")
    print("=" * 80 + "\n")

    auth = HTTPBasicAuth(jenkins_user, jenkins_api_token)

    verify_auth(jenkins_url, auth)

    queue_url  = trigger_build(jenkins_url, jenkins_job_path, auth,
                               blackduck_instance, project_name, version, output_file)
    build_url  = wait_for_build_start(queue_url, auth, jenkins_url, poll_interval)
    build_info = wait_for_build_completion(build_url, auth, jenkins_url, poll_interval, max_wait)
    osl_path   = download_osl_artifact(build_info, auth, jenkins_url,
                                       version, output_dir, output_file)

    print("\n" + "=" * 80)
    print(" SUCCESS ".center(80, "="))
    print(f"OSL file written to: {osl_path}")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
