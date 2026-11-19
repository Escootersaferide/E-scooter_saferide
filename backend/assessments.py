"""Server-graded qualification and per-ride checks."""

from __future__ import annotations

from contextlib import closing
from datetime import datetime, timezone
import json
from pathlib import Path
import random
import secrets
import sqlite3
import time

if __package__:
    from .database import AuthError, UserDatabase, ValidationError
else:
    from database import AuthError, UserDatabase, ValidationError


TRAFFIC_BANK_PATH = Path(__file__).resolve().parents[1] / "assets/questions/traffic.json"
COOLDOWN_SECONDS = 5 * 60
PASS_SCORES = {"qualification": 16, "order": 5}


def readiness(prompt: str, options: list[str], safe_options: list[int]) -> dict:
    return {"category": "readiness", "prompt": prompt, "options": options, "safe": safe_options}


FEELING = readiness(
    "Как вы себя чувствуете прямо сейчас?",
    ["Хорошо, могу сосредоточиться", "Устал(а) или клонит в сон", "Плохо себя чувствую"],
    [0],
)
QUALIFICATION_READINESS = [
    FEELING,
    readiness(
        "Может ли недавно употреблённый алкоголь сейчас влиять на вашу реакцию?",
        ["Нет", "Да или не уверен(а)"],
        [0],
    ),
    readiness(
        "Принимали ли вы лекарства или другие вещества, которые сейчас могут вызвать сонливость?",
        ["Нет", "Да или не уверен(а)"],
        [0],
    ),
    readiness(
        "Можете ли вы уделять внимание дороге и быстро реагировать?",
        ["Да", "Нет или не уверен(а)"],
        [0],
    ),
]
ORDER_READINESS = [
    FEELING,
    readiness(
        "Может ли алкоголь, лекарство или другое вещество сейчас ухудшать вашу реакцию?",
        ["Нет", "Да или не уверен(а)"],
        [0],
    ),
]
ORDER_GENERAL = [
    {
        "category": "general",
        "prompt": "Что стоит проверить перед началом поездки?",
        "options": ["Только заряд", "Тормоза, шины и заряд", "Только цвет самоката"],
        "correct_option": 1,
    },
    {
        "category": "general",
        "prompt": "Что делать, если вы заметили неисправность тормозов во время поездки?",
        "options": [
            "Продолжить поездку на низкой скорости",
            "Доехать до места назначения и сообщить потом",
            "Безопасно остановиться и сообщить о неисправности",
        ],
        "correct_option": 2,
    },
]


def _timestamp(value: int | None) -> str | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value, timezone.utc).isoformat()


def _result(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "completed_at": _timestamp(row["completed_at"]),
        "passed": bool(row["passed"]),
        "readiness_ok": bool(row["readiness_ok"]),
        "score": row["score"],
        "total": row["total"],
    }


def _qualified_at(conn: sqlite3.Connection, user_id: int) -> int | None:
    return conn.execute(
        """
        SELECT min(completed_at) FROM ride_assessments
        WHERE user_id = ? AND kind = 'qualification' AND passed = 1
        """,
        (user_id,),
    ).fetchone()[0]


def _retry_after(conn: sqlite3.Connection, user_id: int, now: int) -> int:
    last_failure = conn.execute(
        """
        SELECT max(completed_at) FROM ride_assessments
        WHERE user_id = ? AND kind = 'order' AND passed = 0
        """,
        (user_id,),
    ).fetchone()[0]
    return 0 if last_failure is None else max(0, last_failure + COOLDOWN_SECONDS - now)


class RideAssessments:
    def __init__(self, db: UserDatabase) -> None:
        self.db = db
        self.traffic = json.loads(TRAFFIC_BANK_PATH.read_text(encoding="utf-8"))

    def overview(self, user_id: int) -> dict:
        with closing(self.db.connect()) as conn:
            conn.execute("BEGIN")
            qualified_at = _qualified_at(conn, user_id)
            retry_after = _retry_after(conn, user_id, int(time.time()))
            orders = conn.execute(
                """
                SELECT * FROM ride_assessments
                WHERE user_id = ? AND kind = 'order' AND completed_at IS NOT NULL
                ORDER BY completed_at DESC, rowid DESC
                """,
                (user_id,),
            )
            return {
                "qualified_at": _timestamp(qualified_at),
                "retry_after_seconds": retry_after,
                "history": [_result(row) for row in orders],
            }

    def start(self, user_id: int, kind: object) -> dict:
        if not isinstance(kind, str) or kind not in PASS_SCORES:
            raise ValidationError("Выберите большой или короткий тест.")

        with closing(self.db.connect()) as conn, conn:
            conn.execute("BEGIN IMMEDIATE")
            now = int(time.time())
            if kind == "order":
                if _qualified_at(conn, user_id) is None:
                    raise AuthError("Сначала пройдите большой тест.", 403)
                retry_after = _retry_after(conn, user_id, now)
                if retry_after:
                    raise AuthError(f"До новой попытки осталось {retry_after} сек.", 429)

            pending = conn.execute(
                """
                SELECT id, questions FROM ride_assessments
                WHERE user_id = ? AND kind = ? AND completed_at IS NULL
                """,
                (user_id, kind),
            ).fetchone()
            if pending is None:
                attempt_id = secrets.token_urlsafe(24)
                questions = self._draw(kind)
                conn.execute(
                    """
                    INSERT INTO ride_assessments (id, user_id, kind, questions, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (attempt_id, user_id, kind, json.dumps(questions, ensure_ascii=False), now),
                )
            else:
                attempt_id = pending["id"]
                questions = json.loads(pending["questions"])
            return {
                "id": attempt_id,
                "min_score": PASS_SCORES[kind],
                "questions": [
                    {key: question[key] for key in ("category", "prompt", "options")}
                    for question in questions
                ],
            }

    def submit(self, user_id: int, attempt_id: object, answers: object) -> dict:
        if not isinstance(attempt_id, str):
            raise ValidationError("Укажите попытку прохождения теста.")
        with closing(self.db.connect()) as conn, conn:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT * FROM ride_assessments WHERE id = ? AND user_id = ?",
                (attempt_id, user_id),
            ).fetchone()
            if row is None:
                raise AuthError("Попытка не найдена.", 404)
            if row["completed_at"] is not None:
                return _result(row)

            questions = json.loads(row["questions"])
            if (
                not isinstance(answers, list)
                or len(answers) != len(questions)
                or any(
                    type(answer) is not int or not 0 <= answer < len(question["options"])
                    for question, answer in zip(questions, answers)
                )
            ):
                raise ValidationError("Ответьте на все вопросы теста.")

            readiness_ok = all(
                answer in question["safe"]
                for question, answer in zip(questions, answers)
                if question["category"] == "readiness"
            )
            knowledge = [
                answer == question["correct_option"]
                for question, answer in zip(questions, answers)
                if question["category"] != "readiness"
            ]
            score = sum(knowledge)
            passed = readiness_ok and score >= PASS_SCORES[row["kind"]]
            updated = conn.execute(
                """
                UPDATE ride_assessments
                SET questions = NULL, completed_at = ?, passed = ?,
                    readiness_ok = ?, score = ?, total = ?
                WHERE id = ? RETURNING *
                """,
                (int(time.time()), passed, readiness_ok, score, len(knowledge), attempt_id),
            ).fetchone()
            return _result(updated)

    def _draw(self, kind: str) -> list[dict]:
        qualification = kind == "qualification"
        traffic_questions = [
            {
                "category": "traffic",
                "prompt": question["prompt"],
                "options": question["options"],
                "correct_option": question["correct_option"],
            }
            for question in random.sample(self.traffic, 20 if qualification else 3)
        ]
        if qualification:
            return [*QUALIFICATION_READINESS, *traffic_questions]
        return [*ORDER_READINESS, *traffic_questions, *ORDER_GENERAL]
