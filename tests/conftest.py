"""Pytest configuration — add the repo root to sys.path so `udp_core` imports."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
