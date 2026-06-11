"""Unit tests for generate-osl-report.py — uses stdlib unittest only."""
import unittest
from unittest.mock import MagicMock, patch, call
from requests.auth import HTTPBasicAuth

from conftest import load_script

mod = load_script("generate-osl-report")

JENKINS_URL      = "https://gtso-jenkins.devops.broadcom.net"
JOB_PATH         = "Black Duck - End User Reports/Generate Notices Report"
EXPECTED_JOB_URL = (
    "https://gtso-jenkins.devops.broadcom.net"
    "/job/Black%20Duck%20-%20End%20User%20Reports"
    "/job/Generate%20Notices%20Report"
)
AUTH = HTTPBasicAuth("ci-user", "api-token-abc")

FAKE_CRUMB = {"Jenkins-Crumb": "abc123"}


# ---------------------------------------------------------------------------
# build_job_url
# ---------------------------------------------------------------------------

class TestBuildJobUrl(unittest.TestCase):
    def test_matches_expected_url(self):
        self.assertEqual(mod.build_job_url(JENKINS_URL, JOB_PATH), EXPECTED_JOB_URL)

    def test_spaces_encoded_as_percent20(self):
        url = mod.build_job_url("https://jenkins.example.com", "My Folder/My Job")
        self.assertIn("%20", url)
        self.assertNotIn(" ", url)

    def test_single_level_job(self):
        url = mod.build_job_url("https://jenkins.example.com", "Simple Job")
        self.assertEqual(url, "https://jenkins.example.com/job/Simple%20Job")

    def test_hyphen_not_encoded(self):
        url = mod.build_job_url(JENKINS_URL, JOB_PATH)
        self.assertNotIn("%2D", url)
        self.assertIn("-", url)

    def test_nested_job_has_job_between_segments(self):
        url = mod.build_job_url("https://j.example.com", "Folder/Job")
        self.assertEqual(url, "https://j.example.com/job/Folder/job/Job")

    def test_buildwithparameters_suffix(self):
        trigger = mod.build_job_url(JENKINS_URL, JOB_PATH) + "/buildWithParameters"
        self.assertEqual(trigger, EXPECTED_JOB_URL + "/buildWithParameters")


# ---------------------------------------------------------------------------
# get_crumb
# ---------------------------------------------------------------------------

class TestGetCrumb(unittest.TestCase):
    def _resp(self, status=200):
        r = MagicMock()
        r.status_code = status
        r.json.return_value = {"crumb": "abc123", "crumbRequestField": "Jenkins-Crumb"}
        r.raise_for_status = MagicMock()
        return r

    @patch("requests.get")
    def test_returns_crumb_header_dict(self, mock_get):
        mock_get.return_value = self._resp()
        self.assertEqual(mod.get_crumb(JENKINS_URL, AUTH), {"Jenkins-Crumb": "abc123"})

    @patch("requests.get")
    def test_no_jsessionid_in_result(self, mock_get):
        mock_get.return_value = self._resp()
        result = mod.get_crumb(JENKINS_URL, AUTH)
        for k in result:
            self.assertNotIn("JSESSIONID", k.upper())

    @patch("requests.get")
    def test_404_returns_empty_dict(self, mock_get):
        mock_get.return_value = self._resp(status=404)
        self.assertEqual(mod.get_crumb(JENKINS_URL, AUTH), {})


# ---------------------------------------------------------------------------
# trigger_build
# ---------------------------------------------------------------------------

class TestTriggerBuild(unittest.TestCase):
    def _trigger_201(self, location="https://gtso-jenkins.devops.broadcom.net/queue/item/42/"):
        r = MagicMock()
        r.status_code = 201
        r.headers = {"Location": location}
        r.text = ""
        return r

    def _trigger_500(self):
        r = MagicMock()
        r.status_code = 500
        r.headers = {}
        r.text = "Server Error"
        return r

    def _call(self, bd_instance="BD-VM", project="proj", version="5.5.2",
              output_file="notices.txt"):
        return mod.trigger_build(
            JENKINS_URL, JOB_PATH, AUTH, bd_instance, project, version, output_file
        )

    @patch("requests.get")          # get_crumb call inside trigger_build
    @patch("requests.post")
    def test_blackduck_instance_uses_hyphen_bd_vm(self, mock_post, mock_get):
        """BlackDuck_Instance MUST be 'BD-VM' (hyphen) — not 'BD_VM' (underscore)."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201()
        self._call(bd_instance="BD-VM")
        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs["params"]["BlackDuck_Instance"], "BD-VM")

    @patch("requests.get")
    @patch("requests.post")
    def test_all_four_params_sent(self, mock_post, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201()
        self._call(bd_instance="BD-VM", project="MyProject",
                   version="5.5.2", output_file="notices.txt")
        _, kwargs = mock_post.call_args
        p = kwargs["params"]
        self.assertEqual(p["BlackDuck_Instance"], "BD-VM")
        self.assertEqual(p["Project_Name"],       "MyProject")
        self.assertEqual(p["Version"],            "5.5.2")
        self.assertEqual(p["Output_File"],        "notices.txt")

    @patch("requests.get")
    @patch("requests.post")
    def test_params_in_query_string_no_body(self, mock_post, mock_get):
        """Parameters must be sent as URL query string (params=), not in body."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201()
        self._call()
        _, kwargs = mock_post.call_args
        self.assertIn("params", kwargs)
        self.assertIsNone(kwargs.get("data"))

    @patch("requests.get")
    @patch("requests.post")
    def test_correct_trigger_url(self, mock_post, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201()
        self._call()
        args, _ = mock_post.call_args
        self.assertEqual(args[0], EXPECTED_JOB_URL + "/buildWithParameters")

    @patch("requests.get")
    @patch("requests.post")
    def test_queue_url_has_api_json_suffix(self, mock_post, mock_get):
        """queue URL = Location header + 'api/json' (matching reference script)."""
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201(
            "https://gtso-jenkins.devops.broadcom.net/queue/item/42/"
        )
        result = self._call()
        self.assertEqual(
            result,
            "https://gtso-jenkins.devops.broadcom.net/queue/item/42/api/json",
        )

    @patch("requests.get")
    @patch("requests.post")
    def test_500_exits(self, mock_post, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_500()
        with self.assertRaises(SystemExit):
            self._call()

    @patch("requests.get")
    @patch("requests.post")
    def test_crumb_sent_in_post_headers(self, mock_post, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"crumb": "abc123", "crumbRequestField": "Jenkins-Crumb"},
            raise_for_status=MagicMock(),
        )
        mock_post.return_value = self._trigger_201()
        self._call()
        _, kwargs = mock_post.call_args
        self.assertEqual(kwargs.get("headers", {}).get("Jenkins-Crumb"), "abc123")


# ---------------------------------------------------------------------------
# wait_for_build_start
# ---------------------------------------------------------------------------

class TestWaitForBuildStart(unittest.TestCase):
    def _queue_resp(self, executable=None, cancelled=False):
        r = MagicMock()
        r.raise_for_status = MagicMock()
        data = {"cancelled": cancelled, "why": "waiting"}
        if executable:
            data["executable"] = executable
        r.json.return_value = data
        return r

    def _crumb_resp(self):
        r = MagicMock()
        r.status_code = 200
        r.raise_for_status = MagicMock()
        r.json.return_value = {"crumb": "abc123", "crumbRequestField": "Jenkins-Crumb"}
        return r

    @patch("time.sleep")
    @patch("requests.get")
    def test_returns_build_url(self, mock_get, _sleep):
        crumb_r = self._crumb_resp()
        queue_r = self._queue_resp(
            executable={"url": "https://jenkins.example.com/job/X/42", "number": 42}
        )
        mock_get.side_effect = [crumb_r, queue_r]
        result = mod.wait_for_build_start(
            "https://jenkins.example.com/queue/item/1/api/json",
            AUTH, JENKINS_URL, 1,
        )
        self.assertIn("job/X/42", result)

    @patch("time.sleep")
    @patch("requests.get")
    def test_polls_until_assigned(self, mock_get, _sleep):
        crumb_r  = self._crumb_resp()
        waiting  = self._queue_resp()
        assigned = self._queue_resp(
            executable={"url": "https://jenkins.example.com/job/X/5", "number": 5}
        )
        # crumb + waiting, crumb + waiting, crumb + assigned
        mock_get.side_effect = [crumb_r, waiting, crumb_r, waiting, crumb_r, assigned]
        mod.wait_for_build_start(
            "https://jenkins.example.com/queue/item/1/api/json",
            AUTH, JENKINS_URL, 1,
        )
        queue_calls = [c for c in mock_get.call_args_list
                       if "queue" in str(c)]
        self.assertEqual(len(queue_calls), 3)

    @patch("time.sleep")
    @patch("requests.get")
    def test_cancelled_exits(self, mock_get, _sleep):
        crumb_r    = self._crumb_resp()
        cancelled  = self._queue_resp(cancelled=True)
        mock_get.side_effect = [crumb_r, cancelled]
        with self.assertRaises(SystemExit):
            mod.wait_for_build_start(
                "https://jenkins.example.com/queue/item/1/api/json",
                AUTH, JENKINS_URL, 1,
            )


# ---------------------------------------------------------------------------
# wait_for_build_completion
# ---------------------------------------------------------------------------

class TestWaitForBuildCompletion(unittest.TestCase):
    def _build_resp(self, building=False, result="SUCCESS"):
        r = MagicMock()
        r.raise_for_status = MagicMock()
        r.json.return_value = {
            "building":          building,
            "result":            result,
            "duration":          5000,
            "estimatedDuration": 10000,
            "url":               "https://jenkins.example.com/job/X/42/",
            "artifacts":         [],
        }
        return r

    def _crumb_resp(self):
        r = MagicMock()
        r.status_code = 200
        r.raise_for_status = MagicMock()
        r.json.return_value = {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"}
        return r

    @patch("time.sleep")
    @patch("requests.get")
    def test_success_returns_build_info(self, mock_get, _sleep):
        mock_get.side_effect = [self._crumb_resp(), self._build_resp()]
        data = mod.wait_for_build_completion(
            "https://jenkins.example.com/job/X/42/",
            AUTH, JENKINS_URL, 1, 60,
        )
        self.assertEqual(data["result"], "SUCCESS")

    @patch("time.sleep")
    @patch("requests.get")
    def test_failure_exits(self, mock_get, _sleep):
        mock_get.side_effect = [self._crumb_resp(), self._build_resp(result="FAILURE")]
        with self.assertRaises(SystemExit):
            mod.wait_for_build_completion(
                "https://jenkins.example.com/job/X/42/",
                AUTH, JENKINS_URL, 1, 60,
            )

    @patch("time.sleep")
    @patch("requests.get")
    def test_timeout_exits(self, mock_get, _sleep):
        mock_get.side_effect = [self._crumb_resp(), self._build_resp(building=True),
                                 self._crumb_resp(), self._build_resp(building=True)] * 10
        with self.assertRaises(SystemExit):
            mod.wait_for_build_completion(
                "https://jenkins.example.com/job/X/42/",
                AUTH, JENKINS_URL, 1, 2,
            )

    @patch("time.sleep")
    @patch("requests.get")
    def test_polls_while_building(self, mock_get, _sleep):
        mock_get.side_effect = [
            self._crumb_resp(), self._build_resp(building=True),
            self._crumb_resp(), self._build_resp(building=True),
            self._crumb_resp(), self._build_resp(),
        ]
        mod.wait_for_build_completion(
            "https://jenkins.example.com/job/X/42/",
            AUTH, JENKINS_URL, 1, 60,
        )
        build_calls = [c for c in mock_get.call_args_list if "api/json" in str(c)
                       and "queue" not in str(c) and "crumb" not in str(c)]
        self.assertEqual(len(build_calls), 3)


# ---------------------------------------------------------------------------
# download_osl_artifact
# ---------------------------------------------------------------------------

class TestDownloadOslArtifact(unittest.TestCase):
    def _artifact_list(self, artifacts):
        r = MagicMock()
        r.raise_for_status = MagicMock()
        r.json.return_value = {"artifacts": artifacts}
        return r

    def _download(self):
        r = MagicMock()
        r.raise_for_status = MagicMock()
        r.iter_content = MagicMock(return_value=[b"data"])
        return r

    def _crumb_resp(self):
        r = MagicMock()
        r.status_code = 200
        r.raise_for_status = MagicMock()
        r.json.return_value = {"crumb": "x", "crumbRequestField": "Jenkins-Crumb"}
        return r

    def _build_info(self, artifacts):
        return {
            "url":       "https://jenkins.example.com/job/X/42/",
            "artifacts": artifacts,
        }

    @patch("os.path.getsize", return_value=512)
    @patch("requests.get")
    def test_finds_artifact_by_output_file_name(self, mock_get, _size):
        artifacts = [
            {"fileName": "notices.txt",  "relativePath": "notices.txt"},
            {"fileName": "build.log",    "relativePath": "build.log"},
        ]
        mock_get.side_effect = [self._crumb_resp(), self._download()]
        with patch("builtins.open", MagicMock()), patch("os.makedirs"):
            mod.download_osl_artifact(
                self._build_info(artifacts), AUTH, JENKINS_URL,
                "5.5.2", "/tmp/osl", "notices.txt",
            )
        download_url = mock_get.call_args_list[1][0][0]
        self.assertIn("notices.txt", download_url)

    @patch("os.path.getsize", return_value=512)
    @patch("requests.get")
    def test_canonical_rmt_filename(self, mock_get, _size):
        artifacts = [{"fileName": "notices.txt", "relativePath": "notices.txt"}]
        mock_get.side_effect = [self._crumb_resp(), self._download()]
        with patch("builtins.open", MagicMock()), patch("os.makedirs"):
            path = mod.download_osl_artifact(
                self._build_info(artifacts), AUTH, JENKINS_URL,
                "5.5.2", "/tmp/osl", "notices.txt",
            )
        self.assertIn(
            "open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_5.5.2_GA.txt",
            path,
        )

    @patch("requests.get")
    def test_no_artifacts_exits(self, mock_get):
        mock_get.return_value = self._crumb_resp()
        with self.assertRaises(SystemExit):
            mod.download_osl_artifact(
                self._build_info([]), AUTH, JENKINS_URL,
                "5.5.2", "/tmp/osl", "notices.txt",
            )

    @patch("os.path.getsize", return_value=512)
    @patch("requests.get")
    def test_fallback_when_exact_name_not_found(self, mock_get, _size):
        artifacts = [
            {"fileName": "open_source_license_notice.txt",
             "relativePath": "osl/open_source_license_notice.txt"},
        ]
        mock_get.side_effect = [self._crumb_resp(), self._download()]
        with patch("builtins.open", MagicMock()), patch("os.makedirs"):
            path = mod.download_osl_artifact(
                self._build_info(artifacts), AUTH, JENKINS_URL,
                "5.5.2", "/tmp/osl", "not_present.txt",
            )
        self.assertIn("open_source_license_Platform_Automation_Toolkit", path)


if __name__ == "__main__":
    unittest.main()
