"""JSON logger with secret redaction.

Phase 4: the previous version defined SECRET_PATTERN but never applied it —
fields like 'password', 'token', 'secret', 'key' could be logged verbatim.
This version walks each log record's message and any dict-like `extra` fields,
redacting matched values.
"""
from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

# Match common credential field names. Word boundaries prevent matching inside
# unrelated identifiers (e.g. "keystone" should not match "key").
SECRET_FIELD = re.compile(
    r"\b(password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|"
    r"secret[_-]?key|authorization|bearer|cookie)\b",
    re.IGNORECASE,
)

# Match inline KEY=VALUE or KEY: VALUE pairs in free-form text.
INLINE_PAIR = re.compile(
    r"(?P<key>(?:password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key|"
    r"secret[_-]?key|authorization|bearer|cookie))"
    r"(?P<sep>\s*[:=]\s*)"
    r"(?P<val>[^\s,;}]+)",
    re.IGNORECASE,
)

REDACTED = "<REDACTED>"


def _redact_text(text: str) -> str:
    return INLINE_PAIR.sub(lambda m: f"{m.group('key')}{m.group('sep')}{REDACTED}", text)


def _redact_value(key: str, value: Any) -> Any:
    if SECRET_FIELD.search(key):
        return REDACTED
    if isinstance(value, str):
        return _redact_text(value)
    if isinstance(value, dict):
        return {k: _redact_value(k, v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return type(value)(_redact_value(key, v) for v in value)
    return value


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": _redact_text(record.getMessage()),
        }
        # Include any structured fields the caller attached via `extra=`.
        # logging puts them on the record as attributes — anything not in the
        # standard LogRecord attribute set is fair game.
        std_attrs = {
            "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
            "module", "exc_info", "exc_text", "stack_info", "lineno", "funcName",
            "created", "msecs", "relativeCreated", "thread", "threadName",
            "processName", "process", "getMessage", "message",
        }
        for k, v in record.__dict__.items():
            if k.startswith("_") or k in std_attrs:
                continue
            payload[k] = _redact_value(k, v)
        if record.exc_info:
            payload["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.propagate = False
    return logger
