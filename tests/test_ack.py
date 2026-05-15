from udp_core.ack.ack_manager import AckManager


def test_mark_and_check(tmp_path):
    ack = AckManager(str(tmp_path / "acks"))
    assert ack.is_done("alpha") is False
    ack.mark_done("alpha")
    assert ack.is_done("alpha") is True


def test_error_separate_from_done(tmp_path):
    ack = AckManager(str(tmp_path / "acks"))
    ack.mark_error("beta", "boom")
    assert ack.is_done("beta") is False
    assert (tmp_path / "acks" / "beta.err").read_text() == "boom"
