import io
import json
import logging

from udp_core.logging.logger import JsonFormatter, _redact_text, _redact_value, get_logger


def test_logger_emits_json():
    buf = io.StringIO()
    handler = logging.StreamHandler(buf)
    handler.setFormatter(JsonFormatter())
    log = logging.getLogger("test_logger.json")
    log.handlers = [handler]
    log.setLevel(logging.INFO)
    log.propagate = False

    log.info("hello")
    payload = json.loads(buf.getvalue().strip().splitlines()[-1])
    assert payload["message"] == "hello"
    assert payload["level"] == "INFO"
    assert payload["logger"] == "test_logger.json"


def test_redacts_inline_pair_in_message():
    redacted = _redact_text("connecting with password=hunter2 user=alice")
    assert "hunter2" not in redacted
    assert "<REDACTED>" in redacted
    assert "user=alice" in redacted  # non-secret key untouched


def test_redacts_extra_field_by_key_name():
    out = _redact_value("api_key", "sk-test-1234")
    assert out == "<REDACTED>"


def test_does_not_match_unrelated_identifier():
    # "keystone" should NOT match "key" due to word boundary.
    out = _redact_value("keystone_host", "example.com")
    assert out == "example.com"


def test_extra_dict_is_walked():
    out = _redact_value("conn", {"user": "alice", "password": "hunter2", "host": "h"})
    assert out == {"user": "alice", "password": "<REDACTED>", "host": "h"}


def test_get_logger_is_idempotent():
    a = get_logger("test_logger.idem")
    b = get_logger("test_logger.idem")
    assert len(a.handlers) == 1
    assert a is b
