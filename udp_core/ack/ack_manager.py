from pathlib import Path


class AckManager:
    def __init__(self, root: str):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    def mark_done(self, name: str):
        (self.root / f"{name}.ack").write_text("done", encoding="utf-8")

    def is_done(self, name: str) -> bool:
        return (self.root / f"{name}.ack").exists()

    def mark_error(self, name: str, message: str):
        (self.root / f"{name}.err").write_text(message, encoding="utf-8")
