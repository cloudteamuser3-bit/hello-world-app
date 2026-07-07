"""Cloud Run Job entrypoint.

Runs once: generates a small text file and uploads it to a GCS bucket, then
exits. Cloud Run Jobs (unlike Services) are meant for exactly this kind of
run-to-completion task — there's no server to keep alive.

Configuration comes entirely from environment variables, which are set on
the Cloud Run Job resource by Terraform (see the infra repo). Nothing here
is hardcoded to a specific environment.
"""

from __future__ import annotations

import os
import sys
from datetime import UTC, datetime

from google.cloud import storage


class ConfigError(RuntimeError):
    """Raised when a required environment variable is missing."""


def generate_content() -> str:
    """Return the text content to write to the file.

    Kept separate from I/O so it can be unit tested without touching GCS.
    """
    timestamp = datetime.now(UTC).isoformat()
    environment = os.environ.get("ENVIRONMENT", "unknown")
    return f"Hello, World!\nEnvironment: {environment}\nGenerated at: {timestamp}\n"


def upload_file(bucket_name: str, file_name: str, content: str, client: storage.Client | None = None) -> str:
    """Upload `content` to `file_name` in `bucket_name`. Returns the gs:// URI.

    Accepts an optional pre-built client so tests can inject a mock instead
    of hitting real GCS.
    """
    client = client or storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    blob.upload_from_string(content, content_type="text/plain")
    return f"gs://{bucket_name}/{file_name}"


def get_required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ConfigError(f"Required environment variable '{name}' is not set")
    return value


def main() -> int:
    try:
        bucket_name = get_required_env("BUCKET_NAME")
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    file_name = os.environ.get("FILE_NAME", "hello_world.txt")
    content = generate_content()

    try:
        uri = upload_file(bucket_name, file_name, content)
    except Exception as exc:  # noqa: BLE001 - top-level job entrypoint, want to log any failure
        print(f"ERROR: failed to upload file: {exc}", file=sys.stderr)
        return 1

    print(f"Success: uploaded file to {uri}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
