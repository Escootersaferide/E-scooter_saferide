FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SCOOT_HOST=0.0.0.0 \
    SCOOT_DB_PATH=/data/scoot.db \
    SCOOT_CORS_ORIGIN=https://escootersaferide.github.io

WORKDIR /app
COPY backend/__init__.py backend/database.py backend/schema.sql backend/server.py ./backend/

CMD ["python", "-m", "backend.server"]
