from unittest.mock import MagicMock

import pytest

from app.main import ConfigError, generate_content, get_required_env, main, upload_file


def test_generate_content_includes_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ENVIRONMENT", "staging")
    content = generate_content()
    assert "Hello, World!" in content
    assert "Environment: staging" in content
    assert "Generated at:" in content


def test_generate_content_defaults_environment_to_unknown(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    content = generate_content()
    assert "Environment: unknown" in content


def test_get_required_env_present(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SOME_VAR", "value")
    assert get_required_env("SOME_VAR") == "value"


def test_get_required_env_missing_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("MISSING_VAR", raising=False)
    with pytest.raises(ConfigError):
        get_required_env("MISSING_VAR")


def test_upload_file_uses_mock_client() -> None:
    mock_client = MagicMock()
    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_client.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob

    uri = upload_file("my-bucket", "hello_world.txt", "hello", client=mock_client)

    mock_client.bucket.assert_called_once_with("my-bucket")
    mock_bucket.blob.assert_called_once_with("hello_world.txt")
    mock_blob.upload_from_string.assert_called_once_with("hello", content_type="text/plain")
    assert uri == "gs://my-bucket/hello_world.txt"


def test_main_returns_1_when_bucket_name_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("BUCKET_NAME", raising=False)
    assert main() == 1


def test_main_returns_0_on_success(monkeypatch: pytest.MonkeyPatch, mocker=None) -> None:
    monkeypatch.setenv("BUCKET_NAME", "my-bucket")
    monkeypatch.setenv("FILE_NAME", "hello_world.txt")

    from unittest.mock import patch

    with patch("app.main.upload_file", return_value="gs://my-bucket/hello_world.txt") as mock_upload:
        assert main() == 0
        mock_upload.assert_called_once()


def test_main_returns_1_on_upload_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("BUCKET_NAME", "my-bucket")

    from unittest.mock import patch

    with patch("app.main.upload_file", side_effect=RuntimeError("boom")):
        assert main() == 1
