"""YAML config loader with safe env-var substitution.

Phase 4: replaces the previous naive `text.replace("${" + key + "}", value)`,
which (a) could not detect missing keys, (b) collided on shared prefixes, and
(c) did not understand `${VAR:-default}`.

This version uses an explicit regex matching `${VAR}` and `${VAR:-default}`,
raises a MissingEnvVar error if a required key is unset and no default is
provided, and never substitutes partially-matched names.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

# ${VAR}  or  ${VAR:-default-with-no-newline-or-rightbrace}
_PLACEHOLDER = re.compile(
    r"\$\{([A-Z_][A-Z0-9_]*)(?::-([^}]*))?\}",
)


class MissingEnvVar(KeyError):
    """Raised when a placeholder references an env var that is unset and has no default."""


@dataclass
class UdpConfig:
    name: str
    source_type: str
    target_table: str
    primary_key: str | None = None
    incremental_column: str | None = None


def substitute(text: str, env: dict[str, str] | None = None) -> str:
    """Substitute ${VAR} and ${VAR:-default} placeholders against env."""
    env = env if env is not None else dict(os.environ)

    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        default = match.group(2)
        if key in env:
            return env[key]
        if default is not None:
            return default
        raise MissingEnvVar(key)

    return _PLACEHOLDER.sub(repl, text)


def load_yaml_config(path: str | Path, env: dict[str, str] | None = None) -> Any:
    raw = Path(path).read_text(encoding="utf-8")
    substituted = substitute(raw, env)
    return yaml.safe_load(substituted)
