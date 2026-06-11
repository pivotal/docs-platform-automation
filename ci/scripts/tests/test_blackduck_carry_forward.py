"""Unit tests for blackduck-carry-forward-justifications.py — uses stdlib unittest only."""
import unittest
from unittest.mock import MagicMock, patch

from conftest import load_script

mod = load_script("blackduck-carry-forward-justifications")

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


def _component(name, version, usages=None, comment=None,
               policy_status="IN_VIOLATION", ignored=False, href=None):
    href = href or f"{BD_URL}/api/bom/{name}-{version}"
    return {
        "componentName": name,
        "componentVersionName": version,
        "usages": usages or [],
        "comment": comment,
        "policyStatus": policy_status,
        "ignored": ignored,
        "_meta": {"href": href},
    }


# ---------------------------------------------------------------------------
# get_previous_component_data
# ---------------------------------------------------------------------------

class TestGetPreviousComponentData(unittest.TestCase):
    @patch("requests.get")
    def test_filters_by_license_policy_category(self, mock_get):
        """Previous version fetch must include filter=policyCategory:LICENSE."""
        mock_get.return_value = _make_response([])
        mod.get_previous_component_data(BEARER, VERSION_URL)

        url_called = mock_get.call_args[0][0]
        self.assertIn("filter=policyCategory:LICENSE", url_called)

    @patch("requests.get")
    def test_stores_usages_by_name_and_version(self, mock_get):
        items = [
            _component("libA", "1.0", usages=["MERELY_AGGREGATED"]),
            _component("libB", "2.0", usages=["DYNAMICALLY_LINKED"], comment="approved"),
        ]
        mock_get.return_value = _make_response(items)

        data, name_map = mod.get_previous_component_data(BEARER, VERSION_URL)

        self.assertIn("libA@1.0", data)
        self.assertEqual(data["libA@1.0"]["usages"], ["MERELY_AGGREGATED"])
        self.assertIn("libB@2.0", data)
        self.assertEqual(data["libB@2.0"]["comment"], "approved")

    @patch("requests.get")
    def test_builds_name_only_map(self, mock_get):
        items = [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])]
        mock_get.return_value = _make_response(items)

        _, name_map = mod.get_previous_component_data(BEARER, VERSION_URL)
        self.assertEqual(name_map["libA"], ["MERELY_AGGREGATED"])

    @patch("requests.get")
    def test_handles_pagination(self, mock_get):
        page1 = _make_response(
            [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])],
            next_url=f"{VERSION_URL}/components?page=2"
        )
        page2 = _make_response(
            [_component("libB", "2.0", usages=["DYNAMICALLY_LINKED"])]
        )
        mock_get.side_effect = [page1, page2]

        data, _ = mod.get_previous_component_data(BEARER, VERSION_URL)
        self.assertEqual(len(data), 2)
        self.assertIn("libA@1.0", data)
        self.assertIn("libB@2.0", data)


# ---------------------------------------------------------------------------
# carry_forward_data
# ---------------------------------------------------------------------------

class TestCarryForwardData(unittest.TestCase):
    def _run(self, current_items, prev_data, name_to_usage=None, dry_run=False):
        mock_resp = _make_response(current_items)
        with patch("requests.get", return_value=mock_resp), \
             patch("requests.put") as mock_put:
            put_resp = MagicMock()
            put_resp.raise_for_status = MagicMock()
            mock_put.return_value = put_resp
            mod.carry_forward_data(
                BD_URL, BEARER, VERSION_URL,
                prev_data, name_to_usage or {},
                dry_run=dry_run,
            )
            return mock_put

    def test_exact_match_carries_usage(self):
        current = [_component("libA", "1.0", usages=[])]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev)
        self.assertTrue(mock_put.called)
        payload = mock_put.call_args[1]["json"]
        self.assertEqual(payload["usages"], ["MERELY_AGGREGATED"])

    def test_name_only_match_carries_usage(self):
        current  = [_component("libA", "2.0", usages=[])]
        name_map = {"libA": ["MERELY_AGGREGATED"]}

        mock_put = self._run(current, {}, name_to_usage=name_map)
        self.assertTrue(mock_put.called)
        payload = mock_put.call_args[1]["json"]
        self.assertEqual(payload["usages"], ["MERELY_AGGREGATED"])

    def test_skips_ignored_components(self):
        current = [_component("libA", "1.0", usages=[], ignored=True)]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev)
        self.assertFalse(mock_put.called)

    def test_skips_non_in_violation_components(self):
        current = [_component("libA", "1.0", usages=[], policy_status="NOT_IN_VIOLATION")]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev)
        self.assertFalse(mock_put.called)

    def test_skips_when_usage_already_matches(self):
        current = [_component("libA", "1.0", usages=["MERELY_AGGREGATED"])]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev)
        self.assertFalse(mock_put.called)

    def test_skips_when_no_match_in_previous(self):
        current = [_component("libNew", "3.0", usages=[])]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev)
        self.assertFalse(mock_put.called)

    def test_also_carries_comment_on_exact_match(self):
        current = [_component("libA", "1.0", usages=[], comment=None)]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": "Reviewed"}}

        mock_put = self._run(current, prev)
        payload = mock_put.call_args[1]["json"]
        self.assertEqual(payload.get("comment"), "Reviewed")

    def test_dry_run_does_not_call_put(self):
        current = [_component("libA", "1.0", usages=[])]
        prev    = {"libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None}}

        mock_put = self._run(current, prev, dry_run=True)
        self.assertFalse(mock_put.called)

    def test_handles_pagination(self):
        page1 = _make_response(
            [_component("libA", "1.0", usages=[])],
            next_url=f"{VERSION_URL}/components?page=2"
        )
        page2 = _make_response([_component("libB", "2.0", usages=[])])
        prev  = {
            "libA@1.0": {"usages": ["MERELY_AGGREGATED"], "comment": None},
            "libB@2.0": {"usages": ["DYNAMICALLY_LINKED"], "comment": None},
        }

        with patch("requests.get", side_effect=[page1, page2]), \
             patch("requests.put") as mock_put:
            put_resp = MagicMock()
            put_resp.raise_for_status = MagicMock()
            mock_put.return_value = put_resp
            mod.carry_forward_data(BD_URL, BEARER, VERSION_URL, prev, {})

        self.assertEqual(mock_put.call_count, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
