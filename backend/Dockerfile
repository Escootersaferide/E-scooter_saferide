FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SAFERIDE_HOST=0.0.0.0 \
    SAFERIDE_DB_PATH=/data/scoot.db \
    SAFERIDE_CORS_ORIGIN=https://escootersaferide.github.io

WORKDIR /app
COPY backend/__init__.py backend/assessments.py backend/database.py backend/schema.sql backend/server.py ./backend/
COPY assets/questions/traffic.json ./assets/questions/traffic.json

CMD ["python", "-m", "backend.server"]
