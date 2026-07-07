# ---------- Builder stage ----------
FROM python:3.11-slim AS builder

ARG ZOU_VERSION
RUN test -n "$ZOU_VERSION" || (echo "ZOU_VERSION build arg is required" >&2; exit 1)
ENV ZOU_VERSION=${ZOU_VERSION}

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

RUN git clone --depth=1 --branch "${ZOU_VERSION}" https://github.com/cgwire/zou.git .

# Create a virtualenv for Zou + dependencies.
RUN python -m venv /opt/venv \
  && . /opt/venv/bin/activate \
  && pip install --upgrade pip \
  && pip install --no-cache-dir gunicorn psycopg2-binary \
  && pip install --no-cache-dir -r requirements.txt \
  && pip install --no-cache-dir .

# Drop source-control metadata and non-runtime folders from the image.
RUN rm -rf .git tests docs

# ---------- Runtime stage ----------
FROM python:3.11-slim

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

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app
COPY gunicorn.conf.py /app/gunicorn.conf.py

ENV FLASK_APP=zou.app
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

CMD ["gunicorn", "-c", "gunicorn.conf.py", "zou.app:app"]
