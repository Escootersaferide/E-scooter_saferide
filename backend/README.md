# Scoot Auth Backend (SQLite + Python)

Локальный REST API сервер и SQLite-база данных для хранения учётных записей пользователей (`email`, `phone`, `password_hash`) и сессий авторизации. Использует только стандартную библиотеку Python 3 (без внешних зависимостей).

## Схема БД (`backend/schema.sql`)

- `users`:
  - `id` — `INTEGER PRIMARY KEY AUTOINCREMENT`
  - `email` — `TEXT NOT NULL UNIQUE COLLATE NOCASE` (нормализуется в нижний регистр)
  - `phone` — `TEXT NOT NULL UNIQUE` (нормализуется в формат `+<цифры>`, `8XXXXXXXXXX` → `+7XXXXXXXXXX`)
  - `password_hash` — `TEXT NOT NULL` (PBKDF2-HMAC-SHA256, 600 000 итераций + случайная 16-байтовая соль; открытый пароль никогда не сохраняется)
  - `created_at`, `updated_at` — UTC ISO-8601
- `sessions`:
  - `token_hash` — `TEXT PRIMARY KEY` (SHA-256 от Bearer-токена)
  - `user_id` — внешний ключ на `users(id)` с `ON DELETE CASCADE`
  - `created_at`, `expires_at` — срок жизни сессии (30 дней)

## Запуск сервера

```bash
python3 backend/server.py --host 127.0.0.1 --port 8000 --db backend/scoot.db
```

Также поддерживаются переменные окружения `SCOOT_HOST`, `SCOOT_PORT`, `SCOOT_DB_PATH`.

## Эндпоинты API

| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/api/health` | Проверка доступности сервера |
| `POST` | `/api/auth/register` | Регистрация (`{"email", "phone", "password"}`) → `201` с `token` и `user` |
| `POST` | `/api/auth/login` | Вход по email или телефону (`{"identifier", "password"}`) → `200` с `token` и `user` |
| `GET` | `/api/auth/me` | Текущий пользователь по заголовку `Authorization: Bearer <token>` |
| `POST` | `/api/auth/logout` | Завершение сессии (`Authorization: Bearer <token>`) |

## Подключение Flutter-приложения

По умолчанию клиент обращается к `http://127.0.0.1:8000`. Для другого адреса (например, Android-эмулятор `http://10.0.2.2:8000`) передайте `--dart-define`:

```bash
flutter run --dart-define=SCOOT_API_URL=http://10.0.2.2:8000
```

## Запуск тестов

```bash
python3 -m unittest discover -s backend -v
```
