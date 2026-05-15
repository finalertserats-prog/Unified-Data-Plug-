from dataclasses import dataclass
from pathlib import Path
import os
import yaml

@dataclass
class UdpConfig:
    name: str
    source_type: str
    target_table: str
    primary_key: str | None = None
    incremental_column: str | None = None

def load_yaml_config(path: str | Path) -> dict:
    text = Path(path).read_text(encoding="utf-8")
    for key, value in os.environ.items():
        text = text.replace("${" + key + "}", value)
    return yaml.safe_load(text)
