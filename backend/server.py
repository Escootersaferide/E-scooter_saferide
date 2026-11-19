"""HTTP API for saferide accounts and ride assessments."""

from __future__ import annotations

import argparse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

if __package__:
    from .assessments import RideAssessments
    from .database import DEFAULT_DB_PATH, AuthError, UnauthorizedError, UserDatabase, ValidationError
else:
    from assessments import RideAssessments
    from database import DEFAULT_DB_PATH, AuthError, UnauthorizedError, UserDatabase, ValidationError

MAX_BODY_BYTES = 16 * 1024


class SaferideHTTPServer(ThreadingHTTPServer):
    """ThreadingHTTPServer bound to a UserDatabase instance."""

    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        db: UserDatabase,
        *,
        cors_origin: str = "*",
    ) -> None:
        self.db = db
        self.assessments = RideAssessments(db)
        self.cors_origin = cors_origin
        super().__init__(server_address, AuthRequestHandler)


class AuthRequestHandler(BaseHTTPRequestHandler):
    server: SaferideHTTPServer
    timeout = 15

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        if _setting("QUIET_LOGS", "") == "1":
            return
        super().log_message(format, *args)

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        try:
            if path == "/api/health":
                self._send_json(HTTPStatus.OK, {"status": "ok"})
                return
            if path == "/api/auth/me":
                user = self._require_user()
                self._send_json(HTTPStatus.OK, {"user": user.to_dict()})
                return
            if path == "/api/rides":
                user = self._require_user()
                self._send_json(HTTPStatus.OK, self.server.assessments.overview(user.id))
                return
            self._send_json(HTTPStatus.NOT_FOUND, {"error": "Маршрут не найден."})
        except AuthError as exc:
            self._send_json(exc.status_code, {"error": exc.message})

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        try:
            if path == "/api/auth/register":
                payload = self._read_json_body()
                user = self.server.db.create_user(
                    email=payload.get("email", ""),
                    phone=payload.get("phone", ""),
                    password=payload.get("password", ""),
                )
                token = self.server.db.create_session(user.id)
                self._send_json(
                    HTTPStatus.CREATED,
                    {"token": token, "user": user.to_dict()},
                )
                return

            if path == "/api/auth/login":
                payload = self._read_json_body()
                identifier = (
                    payload.get("identifier")
                    or payload.get("email")
                    or payload.get("phone")
                    or ""
                )
                user = self.server.db.authenticate(
                    identifier=identifier,
                    password=payload.get("password", ""),
                )
                token = self.server.db.create_session(user.id)
                self._send_json(
                    HTTPStatus.OK,
                    {"token": token, "user": user.to_dict()},
                )
                return

            if path == "/api/auth/logout":
                token = self._extract_bearer_token()
                if token is None:
                    raise UnauthorizedError("Требуется авторизация.")
                self.server.db.revoke_session(token)
                self._send_json(HTTPStatus.OK, {"ok": True})
                return

            if path == "/api/rides/start":
                user = self._require_user()
                payload = self._read_json_body()
                attempt = self.server.assessments.start(user.id, payload.get("kind"))
                self._send_json(HTTPStatus.OK, attempt)
                return

            if path == "/api/rides/submit":
                user = self._require_user()
                payload = self._read_json_body()
                result = self.server.assessments.submit(
                    user.id, payload.get("id"), payload.get("answers")
                )
                self._send_json(HTTPStatus.OK, result)
                return

            self._send_json(HTTPStatus.NOT_FOUND, {"error": "Маршрут не найден."})
        except AuthError as exc:
            self._send_json(exc.status_code, {"error": exc.message})

    def _read_json_body(self) -> dict[str, Any]:
        raw_length = self.headers.get("Content-Length")
        if raw_length is None:
            raise ValidationError("Ожидается JSON-тело запроса.")
        try:
            length = int(raw_length)
        except ValueError as exc:
            raise ValidationError("Некорректный заголовок Content-Length.") from exc
        if length < 0 or length > MAX_BODY_BYTES:
            raise ValidationError("Слишком большой размер запроса.")
        raw_bytes = self.rfile.read(length)
        try:
            decoded = json.loads(raw_bytes.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValidationError("Некорректный JSON в теле запроса.") from exc
        if not isinstance(decoded, dict):
            raise ValidationError("Тело запроса должно быть JSON-объектом.")
        return decoded

    def _extract_bearer_token(self) -> str | None:
        header = self.headers.get("Authorization", "")
        prefix = "Bearer "
        if not header.startswith(prefix):
            return None
        token = header[len(prefix) :].strip()
        return token or None

    def _require_user(self):
        token = self._extract_bearer_token()
        if token is None:
            raise UnauthorizedError("Требуется авторизация.")
        user = self.server.db.get_user_by_token(token)
        if user is None:
            raise UnauthorizedError("Сессия недействительна или истекла.")
        return user

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", self.server.cors_origin)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization",
        )

    def _send_json(self, status_code: int, body: dict[str, object]) -> None:
        encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def _setting(name: str, default: str) -> str:
    return os.environ.get(f"SAFERIDE_{name}", os.environ.get(f"SCOOT_{name}", default))


def create_server(
    *,
    host: str = "127.0.0.1",
    port: int = 8000,
    db_path: str | Path | None = None,
    cors_origin: str = "*",
    pbkdf2_iterations: int | None = None,
) -> SaferideHTTPServer:
    resolved_db = (
        Path(db_path)
        if db_path is not None
        else Path(_setting("DB_PATH", str(DEFAULT_DB_PATH)))
    )
    db_kwargs: dict[str, Any] = {}
    if pbkdf2_iterations is not None:
        db_kwargs["pbkdf2_iterations"] = pbkdf2_iterations
    db = UserDatabase(resolved_db, **db_kwargs)
    return SaferideHTTPServer((host, port), db, cors_origin=cors_origin)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the saferide API.",
    )
    parser.add_argument(
        "--host",
        default=_setting("HOST", "127.0.0.1"),
        help="Host address to bind (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=_setting("PORT", os.environ.get("PORT", "8000")),
        help="Port to listen on (default: SAFERIDE_PORT, PORT, or 8000)",
    )
    parser.add_argument(
        "--db",
        default=_setting("DB_PATH", str(DEFAULT_DB_PATH)),
        help="Path to SQLite database file",
    )
    parser.add_argument(
        "--cors-origin",
        default=_setting("CORS_ORIGIN", "*"),
        help="Allowed browser origin (default: *)",
    )
    args = parser.parse_args()

    server = create_server(
        host=args.host,
        port=args.port,
        db_path=args.db,
        cors_origin=args.cors_origin,
    )
    print(f"saferide API listening on http://{args.host}:{args.port} (DB: {args.db})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
