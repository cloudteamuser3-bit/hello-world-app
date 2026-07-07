#!/usr/bin/env bash
set -euo pipefail

echo "==> pytest"
pytest --cov=app --cov-report=term-missing
