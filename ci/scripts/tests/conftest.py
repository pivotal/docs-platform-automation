"""Shared pytest fixtures and module-import helpers.

Scripts in ci/scripts/ have hyphens in their filenames which prevents normal
Python imports.  _load_script() uses importlib to load them by file path.
"""
import importlib.util
import pathlib

_SCRIPTS_DIR = pathlib.Path(__file__).parent.parent


def load_script(stem: str):
    """Load a hyphenated script from ci/scripts/ as a module.

    Example:
        mod = load_script("generate-osl-report")
    """
    path = _SCRIPTS_DIR / f"{stem}.py"
    spec = importlib.util.spec_from_file_location(stem.replace("-", "_"), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
