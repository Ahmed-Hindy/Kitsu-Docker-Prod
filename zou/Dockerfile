# ---------- Builder stage ----------
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    build-essential \
    git \
    libpq-dev \
    libmagic1 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG ZOU_VERSION=v1.0.1
RUN git clone --depth=1 --branch ${ZOU_VERSION} https://github.com/cgwire/zou.git .

# Create a virtualenv for zou + deps
RUN python -m venv /opt/venv \
  && . /opt/venv/bin/activate \
  && pip install --upgrade pip \
  && pip install --no-cache-dir gunicorn psycopg2-binary \
  && pip install --no-cache-dir -r requirements.txt \
  && pip install --no-cache-dir .

# Optional: drop git metadata/tests/docs from app to save space
RUN rm -rf .git tests docs

# ---------- Runtime stage ----------
FROM python:3.11-slim

# Only runtime libs; no build-essential, no git, no libpq-dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libpq5 \
    libmagic1 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy virtualenv and app from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app
COPY ../gunicorn.conf.py /app/gunicorn.conf.py

ENV FLASK_APP=zou.app
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

CMD ["gunicorn", "-c", "gunicorn.conf.py", "zou.app:app"]
