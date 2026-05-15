"""Retry decorator with whitelist + backoff.

Phase 4: the previous version caught bare `Exception`, which retried on
non-transient errors (auth failures, schema mismatches) and made
KeyboardInterrupt unreliable. This version accepts an explicit tuple of
exceptions to retry on, defaults to common network errors, and supports
exponential backoff with optional jitter.
"""
from __future__ import annotations

import functools
import random
import time
from collections.abc import Callable
from typing import TypeVar

F = TypeVar("F", bound=Callable[..., object])

# Sensible default: only retry on errors that are typically transient.
DEFAULT_RETRY_ON: tuple[type[BaseException], ...] = (
    ConnectionError,
    TimeoutError,
    OSError,  # covers socket-level errors
)


def retry(
    max_attempts: int = 3,
    delay_seconds: float = 2.0,
    backoff_multiplier: float = 2.0,
    max_delay_seconds: float = 30.0,
    jitter: bool = True,
    retry_on: tuple[type[BaseException], ...] = DEFAULT_RETRY_ON,
):
    """Retry the wrapped callable up to `max_attempts` times on `retry_on` exceptions.

    Wait between attempts grows: delay_seconds, delay * backoff_multiplier, ...
    capped at max_delay_seconds. With jitter, each wait is multiplied by a
    random factor in [0.5, 1.5] to avoid thundering-herd retries.

    KeyboardInterrupt and SystemExit are never caught — they always propagate.
    """
    if max_attempts < 1:
        raise ValueError("max_attempts must be >= 1")

    def decorator(fn: F) -> F:
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            attempt = 0
            wait = delay_seconds
            while True:
                attempt += 1
                try:
                    return fn(*args, **kwargs)
                except (KeyboardInterrupt, SystemExit):
                    raise
                except retry_on:
                    if attempt >= max_attempts:
                        raise
                    sleep_for = wait
                    if jitter:
                        sleep_for *= 0.5 + random.random()
                    time.sleep(sleep_for)
                    wait = min(wait * backoff_multiplier, max_delay_seconds)
        return wrapper  # type: ignore[return-value]

    return decorator
