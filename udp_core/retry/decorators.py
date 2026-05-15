from functools import wraps
import time

def retry(max_attempts=3, delay_seconds=2):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            last_error = None
            for attempt in range(1, max_attempts + 1):
                try:
                    return fn(*args, **kwargs)
                except Exception as exc:
                    last_error = exc
                    if attempt == max_attempts:
                        raise
                    time.sleep(delay_seconds * attempt)
            raise last_error
        return wrapper
    return decorator
