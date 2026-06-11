#!/usr/bin/env python3
"""
generate-osl-report.py

Triggers the Jenkins "Generate Notices Report" job on the Broadcom Jenkins
instance, waits for it to complete successfully, downloads the resulting OSL
notices text artifact, and writes it with the canonical release filename:

  open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_<VERSION>_GA.txt

The output is placed in OUTPUT_DIR (default: generated-osl/) so the calling
Concourse job can `put` it straight to S3 via the osl-* resource.

Required environment variables:
  JENKINS_URL            e.g. https://gtso-jenkins.devops.broadcom.net
  JENKINS_USER           Jenkins username for Basic Auth
  JENKINS_API_TOKEN      Jenkins user API token
  BLACKDUCK_PROJECT_NAME Black Duck project name passed as Project_Name param
  VERSION                Release version e.g. 5.5.1

Optional environment variables:
  OUTPUT_DIR             Output directory (default: generated-osl)
  POLL_INTERVAL_SEC      Seconds between polls (default: 15)
  MAX_WAIT_SEC           Maximum seconds to wait for build (default: 3600)
"""

import logging
import os
import sys
import time

import requests
from requests.auth import HTTPBasicAuth

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

JENKINS_JOB_PATH = (
    "/job/Black%20Duck%20-%20End%20User%20Reports"
    "/job/Generate%20Notices%20Report"
)


def get_env(name, default=None, required=True):
    val = os.environ.get(name, default)
    if required and not val:
        logger.error("Required environment variable %s is not set.", name)
        sys.exit(1)
    return val


# ---------------------------------------------------------------------------
# Jenkins helpers
# ---------------------------------------------------------------------------

def get_crumb(session, jenkins_url):
    """Return (crumb_field, crumb_value) or (None, None) when CSRF is disabled.
    Must be called on the same session used to trigger the build so the session
    cookie set here is carried forward — Jenkins ties the crumb to the session.
    """
    try:
        r = session.get(
            f"{jenkins_url}/crumbIssuer/api/json", timeout=30
        )
        if r.status_code == 404:
            logger.info("CSRF crumb issuer not found — assuming CSRF is disabled.")
            return None, None
        r.raise_for_status()
        data = r.json()
        field = data["crumbRequestField"]
        logger.info("CSRF crumb obtained: %s=<redacted>", field)
        return field, data["crumb"]
    except Exception as exc:
        logger.warning("Could not fetch crumb (%s) — continuing without it.", exc)
        return None, None


def trigger_build(jenkins_url, auth, project_name, version):
    """POST buildWithParameters and return the queue item URL."""
    # Use a persistent session so the JSESSIONID cookie from the crumb fetch
    # is automatically included in the build trigger POST.  Jenkins validates
    # the crumb against the session that issued it — without this the crumb
    # appears invalid and Jenkins returns HTTP 500.
    session = requests.Session()
    session.auth = auth

    crumb_field, crumb_value = get_crumb(session, jenkins_url)
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    if crumb_field:
        headers[crumb_field] = crumb_value

    # Parameters must be sent as form-encoded POST body, not URL query string.
    form_data = {
        "BlackDuck_Instance": "BD_VM",
        "Project_Name": project_name,
        "Version": version,
    }

    url = f"{jenkins_url}{JENKINS_JOB_PATH}/buildWithParameters"
    logger.info("Triggering Jenkins job: %s", url)
    logger.info("  Parameters: %s", form_data)

    r = session.post(url, headers=headers, data=form_data, timeout=30)
    if r.status_code not in (200, 201):
        logger.error(
            "Failed to trigger build: HTTP %d\nResponse headers: %s\nBody (first 500 chars): %s",
            r.status_code,
            dict(r.headers),
            r.text[:500],
        )
        sys.exit(1)

    queue_url = r.headers.get("Location", "").rstrip("/") + "/"
    if not queue_url or queue_url == "/":
        logger.error(
            "No Location header in trigger response. "
            "Response headers: %s", dict(r.headers)
        )
        sys.exit(1)

    logger.info("Build queued: %s", queue_url)
    return queue_url


def wait_for_build_start(queue_url, auth, poll_interval):
    """Poll the queue item until the build executor picks it up."""
    logger.info("Waiting for build to start ...")
    # Jenkins can take a few minutes before assigning an executor.
    max_queue_wait = 1800  # 30 minutes
    elapsed = 0
    while elapsed < max_queue_wait:
        time.sleep(poll_interval)
        elapsed += poll_interval

        r = requests.get(f"{queue_url}api/json", auth=auth, timeout=30)
        r.raise_for_status()
        data = r.json()

        executable = data.get("executable")
        if executable:
            build_url = executable["url"].rstrip("/") + "/"
            build_number = executable["number"]
            logger.info("Build #%d started: %s", build_number, build_url)
            return build_url

        cancelled = data.get("cancelled", False)
        if cancelled:
            logger.error("Build was cancelled while in queue.")
            sys.exit(1)

        why = data.get("why", "unknown reason")
        logger.info("  Still queued (%ds elapsed): %s", elapsed, why)

    logger.error("Timed out after %ds waiting for build to start.", max_queue_wait)
    sys.exit(1)


def wait_for_build_completion(build_url, auth, poll_interval, max_wait):
    """Poll the build URL until building=false, then check result."""
    logger.info("Waiting for build to complete: %s", build_url)
    elapsed = 0
    while elapsed < max_wait:
        time.sleep(poll_interval)
        elapsed += poll_interval

        r = requests.get(f"{build_url}api/json", auth=auth, timeout=30)
        r.raise_for_status()
        data = r.json()

        if not data.get("building", True):
            result = data.get("result", "UNKNOWN")
            duration_s = data.get("duration", 0) / 1000
            logger.info(
                "Build finished: result=%s, duration=%.0fs", result, duration_s
            )
            if result != "SUCCESS":
                logger.error(
                    "Build did not succeed (result=%s). "
                    "Check %sconsole for details.",
                    result,
                    build_url,
                )
                sys.exit(1)
            return

        estimated_s = data.get("estimatedDuration", 0) / 1000
        logger.info(
            "  Still building ... elapsed %ds / estimated %.0fs",
            elapsed,
            estimated_s,
        )

    logger.error("Timed out after %ds waiting for build to complete.", max_wait)
    sys.exit(1)


def download_osl_artifact(build_url, auth, version, output_dir):
    """Find the notices/OSL artifact in the build and save it with the canonical name."""
    r = requests.get(
        f"{build_url}api/json?tree=artifacts[relativePath,fileName]",
        auth=auth,
        timeout=30,
    )
    r.raise_for_status()
    artifacts = r.json().get("artifacts", [])

    if not artifacts:
        logger.error("No artifacts found in build %s", build_url)
        sys.exit(1)

    logger.info("Artifacts in build: %s", [a["fileName"] for a in artifacts])

    # Prefer an artifact that looks like a notices/OSL txt file.
    def is_osl(a):
        name = a["fileName"].lower()
        return name.endswith(".txt") and any(
            kw in name for kw in ("notice", "license", "osl", "open_source")
        )

    candidates = [a for a in artifacts if is_osl(a)]
    if not candidates:
        # Fall back to any .txt file, then any file.
        candidates = [a for a in artifacts if a["fileName"].endswith(".txt")] or artifacts
        logger.warning(
            "No OSL-named artifact found; using first available: %s",
            candidates[0]["fileName"],
        )

    artifact = candidates[0]
    artifact_url = f"{build_url}artifact/{artifact['relativePath']}"
    logger.info("Downloading: %s -> %s", artifact["fileName"], artifact_url)

    r = requests.get(artifact_url, auth=auth, timeout=300, stream=True)
    r.raise_for_status()

    os.makedirs(output_dir, exist_ok=True)
    output_filename = (
        f"open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu"
        f"_{version}_GA.txt"
    )
    output_path = os.path.join(output_dir, output_filename)

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

    jenkins_url = get_env("JENKINS_URL").rstrip("/")
    jenkins_user = get_env("JENKINS_USER")
    jenkins_api_token = get_env("JENKINS_API_TOKEN")
    project_name = get_env("BLACKDUCK_PROJECT_NAME")
    version = get_env("VERSION")
    output_dir = get_env("OUTPUT_DIR", default="generated-osl", required=False)
    poll_interval = int(get_env("POLL_INTERVAL_SEC", default="15", required=False))
    max_wait = int(get_env("MAX_WAIT_SEC", default="3600", required=False))

    print(f"Jenkins URL:    {jenkins_url}")
    print(f"Jenkins User:   {jenkins_user}")
    print(f"BD Project:     {project_name}")
    print(f"Version:        {version}")
    print(f"Output Dir:     {output_dir}")
    print(f"Poll interval:  {poll_interval}s  |  Max wait: {max_wait}s")
    print("=" * 80 + "\n")

    auth = HTTPBasicAuth(jenkins_user, jenkins_api_token)

    queue_url = trigger_build(jenkins_url, auth, project_name, version)
    build_url = wait_for_build_start(queue_url, auth, poll_interval)
    wait_for_build_completion(build_url, auth, poll_interval, max_wait)
    osl_path = download_osl_artifact(build_url, auth, version, output_dir)

    print("\n" + "=" * 80)
    print(" SUCCESS ".center(80, "="))
    print(f"OSL file written to: {osl_path}")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
