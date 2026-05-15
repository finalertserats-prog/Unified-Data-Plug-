
import pytest

from udp_core.retry.decorators import DEFAULT_RETRY_ON, retry


def test_returns_on_first_success():
    calls = {"n": 0}

    @retry(max_attempts=3, delay_seconds=0)
    def fn():
        calls["n"] += 1
        return "ok"

    assert fn() == "ok"
    assert calls["n"] == 1


def test_retries_until_success():
    calls = {"n": 0}

    @retry(max_attempts=4, delay_seconds=0, jitter=False, retry_on=(ValueError,))
    def fn():
        calls["n"] += 1
        if calls["n"] < 3:
            raise ValueError("transient")
        return "ok"

    assert fn() == "ok"
    assert calls["n"] == 3


def test_raises_after_max_attempts():
    calls = {"n": 0}

    @retry(max_attempts=2, delay_seconds=0, jitter=False, retry_on=(ValueError,))
    def fn():
        calls["n"] += 1
        raise ValueError("perma")

    with pytest.raises(ValueError):
        fn()
    assert calls["n"] == 2


def test_does_not_retry_unlisted_exception():
    calls = {"n": 0}

    @retry(max_attempts=5, delay_seconds=0, jitter=False, retry_on=(ValueError,))
    def fn():
        calls["n"] += 1
        raise KeyError("not retried")

    with pytest.raises(KeyError):
        fn()
    assert calls["n"] == 1


def test_keyboard_interrupt_never_caught():
    @retry(max_attempts=5, delay_seconds=0, jitter=False, retry_on=(BaseException,))
    def fn():
        raise KeyboardInterrupt

    with pytest.raises(KeyboardInterrupt):
        fn()


def test_max_attempts_validation():
    with pytest.raises(ValueError):
        retry(max_attempts=0)


def test_backoff_grows_to_cap(monkeypatch):
    sleeps: list[float] = []
    monkeypatch.setattr("udp_core.retry.decorators.time.sleep", lambda s: sleeps.append(s))

    @retry(
        max_attempts=5,
        delay_seconds=1,
        backoff_multiplier=10,
        max_delay_seconds=3,
        jitter=False,
        retry_on=(ValueError,),
    )
    def fn():
        raise ValueError

    with pytest.raises(ValueError):
        fn()
    # waits before attempts 2..5 → 4 sleeps: 1, then 10 capped to 3, then 3, then 3
    assert sleeps == [1, 3, 3, 3]


def test_default_retry_on_is_a_safe_set():
    assert ConnectionError in DEFAULT_RETRY_ON
    assert TimeoutError in DEFAULT_RETRY_ON
    assert Exception not in DEFAULT_RETRY_ON
