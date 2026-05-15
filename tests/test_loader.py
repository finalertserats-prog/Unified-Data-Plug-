import pytest

from udp_core.config.loader import MissingEnvVar, load_yaml_config, substitute


def test_substitutes_simple_var():
    assert substitute("hello ${NAME}", {"NAME": "world"}) == "hello world"


def test_default_used_when_var_missing():
    assert substitute("port=${PORT:-9030}", {}) == "port=9030"


def test_env_overrides_default():
    assert substitute("port=${PORT:-9030}", {"PORT": "5432"}) == "port=5432"


def test_missing_var_with_no_default_raises():
    with pytest.raises(MissingEnvVar):
        substitute("${SECRET_TOKEN}", {})


def test_does_not_collide_on_prefix():
    # PREFIX vs PREFIX_SUFFIX would have broken the old naive str.replace.
    out = substitute(
        "${PREFIX} ${PREFIX_SUFFIX}",
        {"PREFIX": "AA", "PREFIX_SUFFIX": "BB"},
    )
    assert out == "AA BB"


def test_load_yaml_with_substitution(tmp_path):
    cfg = tmp_path / "x.yaml"
    cfg.write_text("name: ${APP_NAME}\nport: ${APP_PORT:-8080}\n")
    parsed = load_yaml_config(cfg, env={"APP_NAME": "udp"})
    # YAML parses 8080 as an int after substitution — that's the YAML loader's
    # behaviour, not the substituter's concern.
    assert parsed == {"name": "udp", "port": 8080}


def test_load_yaml_missing_var_with_no_default_raises(tmp_path):
    cfg = tmp_path / "x.yaml"
    cfg.write_text("token: ${NOT_SET}\n")
    with pytest.raises(MissingEnvVar):
        load_yaml_config(cfg, env={})


def test_special_chars_in_default():
    out = substitute("${X:-a-b-c.d_e}", {})
    assert out == "a-b-c.d_e"
