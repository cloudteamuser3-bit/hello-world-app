#!/usr/bin/env bash
# Lints and format-checks the app. Runs identically on any machine or CI
# platform - no environment variables or CI-specific context required.
set -euo pipefail

echo "==> ruff check"
ruff check .

echo "==> ruff format --check"
ruff format --check .
