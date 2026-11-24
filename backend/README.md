# saferide API (SQLite + Python)

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
python3 -m backend.server --host 127.0.0.1 --port 8000
```

Также поддерживаются переменные окружения `SAFERIDE_HOST`, `SAFERIDE_PORT`, `SAFERIDE_DB_PATH` и `SAFERIDE_CORS_ORIGIN`. Если `SAFERIDE_PORT` не задана, сервер использует `PORT` хостинга.

## Размещение API

1. Создайте на Railway сервис из ветки `kir`. Файл `railway.toml` задаёт сборку контейнера и проверку `/api/health`.
2. Подключите к сервису постоянный том с путём монтирования `/data`. Контейнер использует существующий файл SQLite на этом томе, чтобы сохранять учётные записи между развёртываниями.
3. Создайте публичный HTTPS-домен сервиса. Запрос к `/api/health` возвращает статус `ok` и количество вопросов ПДД в загруженном банке (`traffic_question_count`).
4. Сборка GitHub Pages использует действующий сервис Railway. Чтобы подключить другой API, задайте его базовый HTTPS-адрес без суффикса `/api` в переменной репозитория `SAFERIDE_API_URL` в **Settings → Secrets and variables → Actions → Variables**. При следующем push в `kir` GitHub Pages пересоберёт Flutter с этим адресом.

Контейнер разрешает браузерные запросы с `https://escootersaferide.github.io`. При смене домена сайта укажите новый origin в `SAFERIDE_CORS_ORIGIN`.

## Эндпоинты API

| Метод | Путь | Описание |
| --- | --- | --- |
| `GET` | `/api/health` | Проверка доступности сервера |
| `POST` | `/api/auth/register` | Регистрация (`{"email", "phone", "password"}`) → `201` с `token` и `user` |
| `POST` | `/api/auth/login` | Вход по email или телефону (`{"identifier", "password"}`) → `200` с `token` и `user` |
| `GET` | `/api/auth/me` | Текущий пользователь по заголовку `Authorization: Bearer <token>` |
| `POST` | `/api/auth/logout` | Завершение сессии (`Authorization: Bearer <token>`) |
| `GET` | `/api/rides` | Зачёт большого теста, время до следующей попытки и история коротких тестов |
| `POST` | `/api/rides/start` | Открыть большой (`kind: "qualification"`) или короткий (`kind: "order"`) тест |
| `POST` | `/api/rides/submit` | Отправить ответы по ID попытки (`id`, `answers` как список индексов с нуля) |

Все маршруты `/api/rides` требуют токен авторизации. Короткий тест открывается после зачёта большого. После незачёта короткого теста сервер блокирует новые попытки на пять минут. История хранит дату, зачёт и балл без отдельных ответов о самочувствии.

На большой тест отводится 7 минут, на короткий — 2 минуты. `/api/rides/start`
возвращает оставшееся время в поле `remaining_seconds` и при повторном
открытии сохраняет срок текущей попытки. Сервер отвечает кодом 410 на отправку
ответов после окончания времени. Следующее открытие создаёт новую попытку.

## Подключение Flutter-приложения

По умолчанию клиент обращается к `http://127.0.0.1:8000`. Для другого адреса (например, Android-эмулятор `http://10.0.2.2:8000`) передайте `--dart-define`:

```bash
flutter run --dart-define=SAFERIDE_API_URL=http://10.0.2.2:8000
```

## Запуск тестов

```bash
python3 -m unittest discover -s backend -v
```
