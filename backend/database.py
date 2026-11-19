"""SQLite database layer for storing user email, phone number, and password hashes."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
from pathlib import Path
import re
import secrets
import sqlite3
from typing import Optional

SCHEMA_PATH = Path(__file__).with_name("schema.sql")
LEGACY_DB_PATH = Path(__file__).with_name("scoot.db")
DEFAULT_DB_PATH = (
    LEGACY_DB_PATH if LEGACY_DB_PATH.exists() else Path(__file__).with_name("saferide.db")
)

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PHONE_ALLOWED_RE = re.compile(r"^[+\d\s()\-]+$")

PBKDF2_ALGORITHM = "pbkdf2_sha256"
PBKDF2_ITERATIONS = 600_000
SALT_BYTES = 16
SESSION_TTL_DAYS = 30
MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128


class AuthError(Exception):
    """Base error with HTTP status code for authentication and validation failures."""

    def __init__(self, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class ValidationError(AuthError):
    """Raised when user input does not satisfy format requirements."""

    def __init__(self, message: str) -> None:
        super().__init__(message, status_code=400)


class ConflictError(AuthError):
    """Raised when email or phone number is already registered."""

    def __init__(self, message: str) -> None:
        super().__init__(message, status_code=409)


class UnauthorizedError(AuthError):
    """Raised when credentials or session token are invalid."""

    def __init__(self, message: str) -> None:
        super().__init__(message, status_code=401)


@dataclass(frozen=True)
class User:
    """Public representation of a registered user (never includes password_hash)."""

    id: int
    email: str
    phone: str
    created_at: str

    def to_dict(self) -> dict[str, object]:
        return {
            "id": self.id,
            "email": self.email,
            "phone": self.phone,
            "created_at": self.created_at,
        }


def normalize_email(raw_email: str) -> str:
    if not isinstance(raw_email, str):
        raise ValidationError("Укажите корректный email.")
    email = raw_email.strip().lower()
    if not email or len(email) > 254 or not _EMAIL_RE.match(email):
        raise ValidationError("Укажите корректный email.")
    return email


def normalize_phone(raw_phone: str) -> str:
    if not isinstance(raw_phone, str):
        raise ValidationError("Укажите корректный номер телефона.")
    stripped = raw_phone.strip()
    if not stripped or not _PHONE_ALLOWED_RE.match(stripped):
        raise ValidationError("Укажите корректный номер телефона.")
    digits = re.sub(r"\D", "", stripped)
    if len(digits) == 11 and digits.startswith("8") and not stripped.startswith("+"):
        digits = "7" + digits[1:]
    if not (10 <= len(digits) <= 15):
        raise ValidationError("Номер телефона должен содержать от 10 до 15 цифр.")
    return f"+{digits}"


def validate_password(password: str) -> str:
    if not isinstance(password, str):
        raise ValidationError("Введите пароль.")
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValidationError(
            f"Пароль должен содержать не менее {MIN_PASSWORD_LENGTH} символов."
        )
    if len(password) > MAX_PASSWORD_LENGTH:
        raise ValidationError(
            f"Пароль должен содержать не более {MAX_PASSWORD_LENGTH} символов."
        )
    if not password.strip():
        raise ValidationError("Пароль не может состоять только из пробелов.")
    return password


def hash_password(password: str, *, iterations: int = PBKDF2_ITERATIONS) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256 with a random per-user salt."""
    salt = secrets.token_bytes(SALT_BYTES)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return f"{PBKDF2_ALGORITHM}${iterations}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    """Verify a plaintext password against a stored PBKDF2 hash in constant time."""
    if not isinstance(password, str) or not isinstance(stored_hash, str):
        return False
    parts = stored_hash.split("$")
    if len(parts) != 4 or parts[0] != PBKDF2_ALGORITHM:
        return False
    try:
        iterations = int(parts[1])
        salt = bytes.fromhex(parts[2])
        expected = bytes.fromhex(parts[3])
    except ValueError:
        return False
    candidate = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(candidate, expected)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _format_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class UserDatabase:
    """SQLite repository for users and bearer sessions."""

    def __init__(
        self,
        db_path: str | Path = DEFAULT_DB_PATH,
        *,
        pbkdf2_iterations: int = PBKDF2_ITERATIONS,
    ) -> None:
        self.db_path = Path(db_path)
        self.pbkdf2_iterations = pbkdf2_iterations
        self._init_db()

    def connect(self) -> sqlite3.Connection:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _init_db(self) -> None:
        schema = SCHEMA_PATH.read_text(encoding="utf-8")
        with self.connect() as conn:
            conn.execute("PRAGMA journal_mode = WAL;")
            conn.executescript(schema)

    def create_user(self, *, email: str, phone: str, password: str) -> User:
        normalized_email = normalize_email(email)
        normalized_phone = normalize_phone(phone)
        validated_password = validate_password(password)
        password_hash = hash_password(
            validated_password,
            iterations=self.pbkdf2_iterations,
        )

        with self.connect() as conn:
            existing_email = conn.execute(
                "SELECT id FROM users WHERE email = ?",
                (normalized_email,),
            ).fetchone()
            if existing_email is not None:
                raise ConflictError("Пользователь с таким email уже зарегистрирован.")

            existing_phone = conn.execute(
                "SELECT id FROM users WHERE phone = ?",
                (normalized_phone,),
            ).fetchone()
            if existing_phone is not None:
                raise ConflictError(
                    "Пользователь с таким номером телефона уже зарегистрирован."
                )

            try:
                cursor = conn.execute(
                    """
                    INSERT INTO users (email, phone, password_hash)
                    VALUES (?, ?, ?)
                    """,
                    (normalized_email, normalized_phone, password_hash),
                )
            except sqlite3.IntegrityError as exc:
                error_text = str(exc).lower()
                if "email" in error_text:
                    raise ConflictError(
                        "Пользователь с таким email уже зарегистрирован."
                    ) from exc
                if "phone" in error_text:
                    raise ConflictError(
                        "Пользователь с таким номером телефона уже зарегистрирован."
                    ) from exc
                raise ConflictError("Пользователь уже существует.") from exc

            row = conn.execute(
                "SELECT id, email, phone, created_at FROM users WHERE id = ?",
                (cursor.lastrowid,),
            ).fetchone()
            return self._row_to_user(row)

    def authenticate(self, *, identifier: str, password: str) -> User:
        if not isinstance(identifier, str) or not identifier.strip():
            raise ValidationError("Укажите email или номер телефона.")
        if not isinstance(password, str) or not password:
            raise ValidationError("Введите пароль.")

        raw = identifier.strip()
        if "@" in raw:
            lookup_column = "email"
            lookup_value = normalize_email(raw)
        else:
            lookup_column = "phone"
            lookup_value = normalize_phone(raw)

        with self.connect() as conn:
            row = conn.execute(
                f"SELECT id, email, phone, password_hash, created_at "
                f"FROM users WHERE {lookup_column} = ?",
                (lookup_value,),
            ).fetchone()

        if row is None or not verify_password(password, row["password_hash"]):
            raise UnauthorizedError("Неверный email/телефон или пароль.")

        return self._row_to_user(row)

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        with self.connect() as conn:
            row = conn.execute(
                "SELECT id, email, phone, created_at FROM users WHERE id = ?",
                (user_id,),
            ).fetchone()
        return self._row_to_user(row) if row is not None else None

    def create_session(
        self,
        user_id: int,
        *,
        ttl_days: int = SESSION_TTL_DAYS,
    ) -> str:
        token = secrets.token_urlsafe(32)
        expires_at = _format_utc(_utc_now() + timedelta(days=ttl_days))
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO sessions (token_hash, user_id, expires_at)
                VALUES (?, ?, ?)
                """,
                (_hash_token(token), user_id, expires_at),
            )
        return token

    def get_user_by_token(self, token: str) -> Optional[User]:
        if not isinstance(token, str) or not token.strip():
            return None
        now = _format_utc(_utc_now())
        token_hash = _hash_token(token.strip())
        with self.connect() as conn:
            row = conn.execute(
                """
                SELECT u.id, u.email, u.phone, u.created_at, s.expires_at
                FROM sessions s
                JOIN users u ON u.id = s.user_id
                WHERE s.token_hash = ?
                """,
                (token_hash,),
            ).fetchone()
            if row is None:
                return None
            if row["expires_at"] <= now:
                conn.execute(
                    "DELETE FROM sessions WHERE token_hash = ?",
                    (token_hash,),
                )
                return None
            return self._row_to_user(row)

    def revoke_session(self, token: str) -> bool:
        if not isinstance(token, str) or not token.strip():
            return False
        with self.connect() as conn:
            cursor = conn.execute(
                "DELETE FROM sessions WHERE token_hash = ?",
                (_hash_token(token.strip()),),
            )
            return cursor.rowcount > 0

    @staticmethod
    def _row_to_user(row: sqlite3.Row) -> User:
        return User(
            id=int(row["id"]),
            email=str(row["email"]),
            phone=str(row["phone"]),
            created_at=str(row["created_at"]),
        )
