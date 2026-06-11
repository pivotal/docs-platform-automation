"""Unit tests for generate-osl-report.py — uses stdlib unittest only."""
import io
import os
import sys
import unittest
from unittest.mock import MagicMock, patch
from requests.auth import HTTPBasicAuth

# load_script() uses importlib so the hyphenated filename can be imported
from conftest import load_script

mod = load_script("generate-osl-report")

JENKINS_URL = "https://gtso-jenkins.devops.broadcom.net"
JOB_PATH    = "Black Duck - End User Reports/Generate Notices Report"
EXPECTED_JOB_URL = (
    "https://gtso-jenkins.devops.broadcom.net"
    "/job/Black%20Duck%20-%20End%20User%20Reports"
    "/job/Generate%20Notices%20Report"
)
AUTH = HTTPBasicAuth("ci-user", "api-token-abc")


# ---------------------------------------------------------------------------
# build_job_url
# ---------------------------------------------------------------------------

class TestBuildJobUrl(unittest.TestCase):
    def test_matches_user_provided_url(self):
        """Constructed URL must exactly match the team's browser URL."""
        result = mod.build_job_url(JENKINS_URL, JOB_PATH)
        self.assertEqual(result, EXPECTED_JOB_URL)

    def test_spaces_encoded_as_percent20(self):
        url = mod.build_job_url("https://jenkins.example.com", "My Folder/My Job")
        self.assertIn("%20", url)
        self.assertNotIn(" ", url)

    def test_single_level_job(self):
        url = mod.build_job_url("https://jenkins.example.com", "Simple Job")
        self.assertEqual(url, "https://jenkins.example.com/job/Simple%20Job")

    def test_hyphen_not_encoded(self):
        """Hyphens are safe characters and must not be percent-encoded."""
        url = mod.build_job_url(JENKINS_URL, JOB_PATH)
        self.assertNotIn("%2D", url)
        self.assertIn("-", url)

    def test_trailing_slash_in_path_stripped(self):
        url = mod.build_job_url("https://jenkins.example.com", "/Folder/Job/")
        self.assertEqual(url, "https://jenkins.example.com/job/Folder/job/Job")

    def test_buildwithparameters_suffix(self):
        """Appending /buildWithParameters should produce the full trigger URL."""
        trigger = mod.build_job_url(JENKINS_URL, JOB_PATH) + "/buildWithParameters"
        self.assertEqual(trigger, EXPECTED_JOB_URL + "/buildWithParameters")


# ---------------------------------------------------------------------------
# trigger_build
# ---------------------------------------------------------------------------

class TestTriggerBuild(unittest.TestCase):
    def _mock_201(self, location="https://jenkins.example.com/queue/item/42/"):
        resp = MagicMock()
        resp.status_code = 201
        resp.headers = {"Location": location}
        return resp

    @patch("requests.post")
    def test_sends_form_data_not_query_params(self, mock_post):
        """Parameters MUST be in the POST body (data=), not the URL (params=)."""
        mock_post.return_value = self._mock_201()
        mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "My Project", "5.5.2")

        _, kwargs = mock_post.call_args
        self.assertIn("data", kwargs, "Parameters must be sent as form data")
        self.assertIsNone(
            kwargs.get("params"),
            "Parameters must NOT be sent in the URL query string"
        )

    @patch("requests.post")
    def test_correct_jenkins_parameters(self, mock_post):
        mock_post.return_value = self._mock_201()
        mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "Platform Automation", "5.5.2")

        _, kwargs = mock_post.call_args
        form = kwargs["data"]
        self.assertEqual(form["BlackDuck_Instance"], "BD_VM")
        self.assertEqual(form["Project_Name"], "Platform Automation")
        self.assertEqual(form["Version"], "5.5.2")

    @patch("requests.post")
    def test_correct_trigger_url(self, mock_post):
        mock_post.return_value = self._mock_201()
        mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "proj", "5.5.2")

        args, _ = mock_post.call_args
        self.assertEqual(args[0], EXPECTED_JOB_URL + "/buildWithParameters")

    @patch("requests.post")
    def test_returns_queue_url_with_trailing_slash(self, mock_post):
        mock_post.return_value = self._mock_201(
            "https://jenkins.example.com/queue/item/42"
        )
        result = mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "proj", "5.5.2")
        self.assertEqual(result, "https://jenkins.example.com/queue/item/42/")

    @patch("requests.post")
    def test_500_exits(self, mock_post):
        resp = MagicMock()
        resp.status_code = 500
        resp.headers = {}
        resp.text = "Internal Server Error"
        mock_post.return_value = resp
        with self.assertRaises(SystemExit):
            mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "proj", "5.5.2")

    @patch("requests.post")
    def test_403_exits(self, mock_post):
        resp = MagicMock()
        resp.status_code = 403
        resp.headers = {}
        resp.text = "Forbidden"
        mock_post.return_value = resp
        with self.assertRaises(SystemExit):
            mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "proj", "5.5.2")

    @patch("requests.post")
    def test_missing_location_header_exits(self, mock_post):
        resp = MagicMock()
        resp.status_code = 201
        resp.headers = {}
        mock_post.return_value = resp
        with self.assertRaises(SystemExit):
            mod.trigger_build(JENKINS_URL, JOB_PATH, AUTH, "proj", "5.5.2")


# ---------------------------------------------------------------------------
# wait_for_build_start
# ---------------------------------------------------------------------------

class TestWaitForBuildStart(unittest.TestCase):
    def _queue_response(self, executable=None, cancelled=False):
        resp = MagicMock()
        resp.raise_for_status = MagicMock()
        data = {"cancelled": cancelled, "why": "waiting"}
        if executable:
            data["executable"] = executable
        resp.json.return_value = data
        return resp

    @patch("time.sleep")
    @patch("requests.get")
    def test_returns_build_url_when_executor_assigned(self, mock_get, _sleep):
        mock_get.return_value = self._queue_response(
            executable={"url": "https://jenkins.example.com/job/X/42", "number": 42}
        )
        result = mod.wait_for_build_start(
            "https://jenkins.example.com/queue/item/1/", AUTH, poll_interval=1
        )
        self.assertIn("job/X/42", result)

    @patch("time.sleep")
    @patch("requests.get")
    def test_polls_until_executor_assigned(self, mock_get, _sleep):
        still_waiting = self._queue_response()
        assigned = self._queue_response(
            executable={"url": "https://jenkins.example.com/job/X/5", "number": 5}
        )
        mock_get.side_effect = [still_waiting, still_waiting, assigned]
        mod.wait_for_build_start(
            "https://jenkins.example.com/queue/item/1/", AUTH, poll_interval=1
        )
        self.assertEqual(mock_get.call_count, 3)

    @patch("time.sleep")
    @patch("requests.get")
    def test_cancelled_exits(self, mock_get, _sleep):
        mock_get.return_value = self._queue_response(cancelled=True)
        with self.assertRaises(SystemExit):
            mod.wait_for_build_start(
                "https://jenkins.example.com/queue/item/1/", AUTH, poll_interval=1
            )


# ---------------------------------------------------------------------------
# wait_for_build_completion
# ---------------------------------------------------------------------------

class TestWaitForBuildCompletion(unittest.TestCase):
    def _build_response(self, building=False, result="SUCCESS"):
        resp = MagicMock()
        resp.raise_for_status = MagicMock()
        resp.json.return_value = {
            "building": building,
            "result": result,
            "duration": 5000,
            "estimatedDuration": 10000,
        }
        return resp

    @patch("time.sleep")
    @patch("requests.get")
    def test_success_returns(self, mock_get, _sleep):
        mock_get.return_value = self._build_response(building=False, result="SUCCESS")
        mod.wait_for_build_completion(
            "https://jenkins.example.com/job/X/42/", AUTH, poll_interval=1, max_wait=60
        )

    @patch("time.sleep")
    @patch("requests.get")
    def test_failure_exits(self, mock_get, _sleep):
        mock_get.return_value = self._build_response(building=False, result="FAILURE")
        with self.assertRaises(SystemExit):
            mod.wait_for_build_completion(
                "https://jenkins.example.com/job/X/42/", AUTH, poll_interval=1, max_wait=60
            )

    @patch("time.sleep")
    @patch("requests.get")
    def test_unstable_exits(self, mock_get, _sleep):
        mock_get.return_value = self._build_response(building=False, result="UNSTABLE")
        with self.assertRaises(SystemExit):
            mod.wait_for_build_completion(
                "https://jenkins.example.com/job/X/42/", AUTH, poll_interval=1, max_wait=60
            )

    @patch("time.sleep")
    @patch("requests.get")
    def test_polls_while_building(self, mock_get, _sleep):
        still_building = self._build_response(building=True)
        done = self._build_response(building=False, result="SUCCESS")
        mock_get.side_effect = [still_building, still_building, done]
        mod.wait_for_build_completion(
            "https://jenkins.example.com/job/X/42/", AUTH, poll_interval=1, max_wait=60
        )
        self.assertEqual(mock_get.call_count, 3)

    @patch("time.sleep")
    @patch("requests.get")
    def test_timeout_exits(self, mock_get, _sleep):
        mock_get.return_value = self._build_response(building=True)
        with self.assertRaises(SystemExit):
            mod.wait_for_build_completion(
                "https://jenkins.example.com/job/X/42/", AUTH, poll_interval=1, max_wait=2
            )


# ---------------------------------------------------------------------------
# download_osl_artifact
# ---------------------------------------------------------------------------

class TestDownloadOslArtifact(unittest.TestCase):
    def _artifact_list_response(self, artifacts):
        resp = MagicMock()
        resp.raise_for_status = MagicMock()
        resp.json.return_value = {"artifacts": artifacts}
        return resp

    def _download_response(self, content=b"OSL content here"):
        resp = MagicMock()
        resp.raise_for_status = MagicMock()
        resp.iter_content = MagicMock(return_value=[content])
        return resp

    @patch("os.path.getsize", return_value=1024)
    @patch("requests.get")
    def test_selects_txt_artifact_for_download(self, mock_get, _size):
        artifacts = [
            {"fileName": "open_source_license_notice.txt",
             "relativePath": "osl/open_source_license_notice.txt"},
            {"fileName": "build.log", "relativePath": "build.log"},
        ]
        mock_get.side_effect = [
            self._artifact_list_response(artifacts),
            self._download_response(),
        ]
        with patch("builtins.open", MagicMock()), patch("os.makedirs"):
            mod.download_osl_artifact(
                "https://jenkins.example.com/job/X/42/", AUTH, "5.5.2", "/tmp/osl"
            )
        download_url = mock_get.call_args_list[1][0][0]
        self.assertIn("osl/open_source_license_notice.txt", download_url)

    @patch("os.path.getsize", return_value=512)
    @patch("requests.get")
    def test_output_filename_matches_release_convention(self, mock_get, _size):
        artifacts = [
            {"fileName": "notices.txt", "relativePath": "notices.txt"},
        ]
        mock_get.side_effect = [
            self._artifact_list_response(artifacts),
            self._download_response(),
        ]
        with patch("builtins.open", MagicMock()), patch("os.makedirs"):
            path = mod.download_osl_artifact(
                "https://jenkins.example.com/job/X/42/", AUTH, "5.5.2", "/tmp/osl"
            )
        expected = (
            "open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_5.5.2_GA.txt"
        )
        self.assertIn(expected, path)

    @patch("requests.get")
    def test_no_artifacts_exits(self, mock_get):
        mock_get.return_value = self._artifact_list_response([])
        with self.assertRaises(SystemExit):
            mod.download_osl_artifact(
                "https://jenkins.example.com/job/X/42/", AUTH, "5.5.2", "/tmp/osl"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
