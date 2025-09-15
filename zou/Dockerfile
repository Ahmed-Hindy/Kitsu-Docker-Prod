FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# + libgl1 fixes the exact error; the rest are commonly needed by OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    build-essential git libpq-dev libmagic1 \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth=1 https://github.com/cgwire/zou.git .

RUN pip install --upgrade pip \
 && pip install --no-cache-dir gunicorn psycopg2-binary \
 && pip install --no-cache-dir -r requirements.txt \
 && pip install --no-cache-dir .

ENV FLASK_APP=zou.app
EXPOSE 8000
CMD ["gunicorn","-w","4","-b","0.0.0.0:8000","zou.app:app"]
