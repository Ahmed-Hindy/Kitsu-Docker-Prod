FROM python:3.11-slim

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

RUN pip install --upgrade pip \
  && pip install --no-cache-dir gunicorn psycopg2-binary \
  && pip install --no-cache-dir -r requirements.txt \
  && pip install --no-cache-dir .

COPY ../gunicorn.conf.py /app/gunicorn.conf.py


ENV FLASK_APP=zou.app

CMD ["gunicorn", "-c", "gunicorn.conf.py", "zou.app:app"]

