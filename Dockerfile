# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder
WORKDIR /build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim AS runtime
RUN useradd --create-home --shell /usr/sbin/nologin appuser
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER appuser

# Cloud Run Jobs invoke the container's entrypoint directly and consider
# the job's exit code the source of truth for success/failure.
ENTRYPOINT ["python", "-m", "app.main"]
