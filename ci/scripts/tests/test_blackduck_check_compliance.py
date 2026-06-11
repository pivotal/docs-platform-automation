"""Unit tests for blackduck-check-compliance.py — uses stdlib unittest only."""
import unittest
from unittest.mock import MagicMock, patch

from conftest import load_script

mod = load_script("blackduck-check-compliance")

BD_URL      = "https://broadcom-vmw.app.blackduck.com"
BEARER      = "test-bearer-token"
VERSION_URL = f"{BD_URL}/api/projects/proj-uuid/versions/ver-uuid"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_response(items, next_url=None):
    resp = MagicMock()
    resp.raise_for_status = MagicMock()
    links = []
    if next_url:
        links.append({"rel": "next", "href": next_url})
    resp.json.return_value = {"items": items, "_meta": {"links": links}}
    return resp


def _component(name, version, usages=None, policy_status="IN_VIOLATION"):
    return {
        "componentName": name,
        "componentVersionName": version,
        "usages": usages if usages is not None else [],
        "policyStatus": policy_status,
    }


# ---------------------------------------------------------------------------
# check_compliance
# ---------------------------------------------------------------------------

class TestCheckCompliance(unittest.TestCase):
    def _run(self, items, next_url=None):
        resp = _make_response(items, next_url)
        with patch("requests.get", return_value=resp):
            mod.check_compliance(BD_URL, BEARER, VERSION_URL)

    def test_passes_when_all_components_have_usage(self):
        items = [
            _component("libA", "1.0", usages=["MERELY_AGGREGATED"]),
            _component("libB", "2.0", usages=["DYNAMICALLY_LINKED"]),
        ]
        self._run(items)  # must not raise

    def test_fails_when_component_missing_usage(self):
        items = [_component("libA", "1.0", usages=[])]
        with patch("requests.get", return_value=_make_response(items)):
            with self.assertRaises(SystemExit):
                mod.check_compliance(BD_URL, BEARER, VERSION_URL)

    def test_skips_non_in_violation_components(self):
        """NOT_IN_VIOLATION / OVERRIDDEN components with no usages must not cause failure."""
        items = [
            _component("libA", "1.0", usages=[], policy_status="NOT_IN_VIOLATION"),
            _component("libB", "2.0", usages=[], policy_status="IN_VIOLATION_OVERRIDDEN"),
        ]
        self._run(items)  # must not raise

    def test_filters_request_by_license_policy_category(self):
        """GET request must include filter=policyCategory:LICENSE."""
        with patch("requests.get", return_value=_make_response([])) as mock_get:
            mod.check_compliance(BD_URL, BEARER, VERSION_URL)
        url_called = mock_get.call_args[0][0]
        self.assertIn("filter=policyCategory:LICENSE", url_called)

    def test_mixed_components_fails_on_missing_usage(self):
        """Compliant components do not prevent failure when any component is missing usage."""
        items = [
            _component("libA", "1.0", usages=["MERELY_AGGREGATED"]),
            _component("libB", "2.0", usages=[]),
        ]
        with patch("requests.get", return_value=_make_response(items)):
            with self.assertRaises(SystemExit):
                mod.check_compliance(BD_URL, BEARER, VERSION_URL)

    def test_handles_pagination_fail_on_page2(self):
        """Failure on page 2 must still trigger SystemExit."""
        page1 = _make_response(
            [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])],
            next_url=f"{VERSION_URL}/components?page=2"
        )
        page2 = _make_response([_component("libB", "2.0", usages=[])])
        with patch("requests.get", side_effect=[page1, page2]):
            with self.assertRaises(SystemExit):
                mod.check_compliance(BD_URL, BEARER, VERSION_URL)

    def test_handles_pagination_all_compliant(self):
        page1 = _make_response(
            [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])],
            next_url=f"{VERSION_URL}/components?page=2"
        )
        page2 = _make_response([_component("libB", "2.0", usages=["DYNAMICALLY_LINKED"])])
        with patch("requests.get", side_effect=[page1, page2]):
            mod.check_compliance(BD_URL, BEARER, VERSION_URL)  # must not raise

    def test_empty_component_list_passes(self):
        self._run([])  # no components → compliance trivially passes

    def test_only_checks_usages_not_comment(self):
        """usages present but no comment field → PASS (comment is never checked)."""
        items = [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])]
        self._run(items)  # must not raise


if __name__ == "__main__":
    unittest.main(verbosity=2)
