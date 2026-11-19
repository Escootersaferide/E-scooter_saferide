"""Unit and integration tests for saferide SQLite user database and auth API."""

from __future__ import annotations

import json
import os
from pathlib import Path
import sqlite3
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from backend.database import (
    ConflictError,
    UnauthorizedError,
    UserDatabase,
    ValidationError,
    hash_password,
    normalize_email,
    normalize_phone,
    verify_password,
)
from backend.server import create_server
from backend.assessments import COOLDOWN_SECONDS

# Fast PBKDF2 count solely for test execution speed while testing the real algorithm.
TEST_PBKDF2_ITERATIONS = 10_000


class DatabaseTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "test_saferide.db"
        self.db = UserDatabase(self.db_path, pbkdf2_iterations=TEST_PBKDF2_ITERATIONS)

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def test_normalization_and_validation(self) -> None:
        self.assertEqual(normalize_email("  Rider@Example.COM "), "rider@example.com")
        self.assertEqual(normalize_phone("8 (999) 123-45-67"), "+79991234567")
        self.assertEqual(normalize_phone("+7 999 123 45 67"), "+79991234567")

        with self.assertRaises(ValidationError):
            normalize_email("not-an-email")
        with self.assertRaises(ValidationError):
            normalize_phone("12345")
        with self.assertRaises(ValidationError):
            normalize_phone("abc1234567890")

    def test_password_is_hashed_with_unique_salts_and_never_plaintext(self) -> None:
        h1 = hash_password("SecretPass123", iterations=TEST_PBKDF2_ITERATIONS)
        h2 = hash_password("SecretPass123", iterations=TEST_PBKDF2_ITERATIONS)
        self.assertNotEqual(h1, h2)
        self.assertNotIn("SecretPass123", h1)
        self.assertTrue(verify_password("SecretPass123", h1))
        self.assertFalse(verify_password("WrongPass123", h1))

    def test_create_user_persists_and_prevents_duplicates(self) -> None:
        user = self.db.create_user(
            email="Rider@saferide.ru",
            phone="8 (999) 111-22-33",
            password="SafePassword1!",
        )
        self.assertEqual(user.email, "rider@saferide.ru")
        self.assertEqual(user.phone, "+79991112233")

        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "SELECT email, phone, password_hash FROM users WHERE id = ?",
                (user.id,),
            ).fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "rider@saferide.ru")
        self.assertEqual(row[1], "+79991112233")
        self.assertTrue(row[2].startswith("pbkdf2_sha256$"))
        self.assertNotIn("SafePassword1!", row[2])

        with self.assertRaises(ConflictError):
            self.db.create_user(
                email="RIDER@SAFERIDE.RU",
                phone="+79990000000",
                password="AnotherPassword1!",
            )

        with self.assertRaises(ConflictError):
            self.db.create_user(
                email="other@saferide.ru",
                phone="+7 999 111-22-33",
                password="AnotherPassword1!",
            )

    def test_authenticate_by_email_or_phone(self) -> None:
        created = self.db.create_user(
            email="user@example.com",
            phone="+7 (901) 555-66-77",
            password="Password123",
        )

        by_email = self.db.authenticate(
            identifier="USER@example.com",
            password="Password123",
        )
        by_phone = self.db.authenticate(
            identifier="8 901 555 66 77",
            password="Password123",
        )
        self.assertEqual(by_email.id, created.id)
        self.assertEqual(by_phone.id, created.id)

        with self.assertRaises(UnauthorizedError):
            self.db.authenticate(identifier="user@example.com", password="WrongPassword")
        with self.assertRaises(UnauthorizedError):
            self.db.authenticate(identifier="missing@example.com", password="Password123")

    def test_sessions_lifecycle(self) -> None:
        user = self.db.create_user(
            email="session@example.com",
            phone="+79992223344",
            password="Password123",
        )
        token = self.db.create_session(user.id)
        resolved = self.db.get_user_by_token(token)
        self.assertIsNotNone(resolved)
        self.assertEqual(resolved.id, user.id)

        self.assertTrue(self.db.revoke_session(token))
        self.assertIsNone(self.db.get_user_by_token(token))


class AuthServerTestCase(unittest.TestCase):
    def setUp(self) -> None:
        os.environ["SAFERIDE_QUIET_LOGS"] = "1"
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "api_saferide.db"
        self.server = create_server(
            host="127.0.0.1",
            port=0,
            db_path=self.db_path,
            pbkdf2_iterations=TEST_PBKDF2_ITERATIONS,
        )
        self.port = self.server.server_address[1]
        self.base_url = f"http://127.0.0.1:{self.port}"
        self._thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self._thread.start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self._thread.join(timeout=5)
        self._tmpdir.cleanup()

    def _request(
        self,
        method: str,
        path: str,
        body: dict[str, object] | None = None,
        token: str | None = None,
    ) -> tuple[int, dict[str, object], dict[str, str]]:
        headers: dict[str, str] = {}
        data: bytes | None = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if token is not None:
            headers["Authorization"] = f"Bearer {token}"

        req = Request(f"{self.base_url}{path}", data=data, headers=headers, method=method)
        try:
            with urlopen(req) as response:
                raw = response.read().decode("utf-8")
                parsed = json.loads(raw) if raw else {}
                return response.status, parsed, dict(response.headers.items())
        except HTTPError as err:
            raw = err.read().decode("utf-8")
            parsed = json.loads(raw) if raw else {}
            return err.code, parsed, dict(err.headers.items())

    def test_health_and_cors(self) -> None:
        status, body, headers = self._request("GET", "/api/health")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"status": "ok"})
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "*")

        status, _, headers = self._request("OPTIONS", "/api/auth/register")
        self.assertEqual(status, 204)
        self.assertIn("Authorization", headers.get("Access-Control-Allow-Headers", ""))

    def test_qualification_controls_orders_and_cooldown_survives_reopening_database(self):
        def register(email, phone):
            status, body, _ = self._request(
                "POST", "/api/auth/register",
                {"email": email, "phone": phone, "password": "TestPassword123"},
            )
            self.assertEqual(status, 201)
            return body["token"]

        token = register("rider@example.test", "+79999990001")
        other_token = register("other@example.test", "+79999990002")
        start = "/api/rides/start"
        submit = "/api/rides/submit"

        def answers_for(attempt):
            with self.server.db.connect() as conn:
                saved = conn.execute(
                    "SELECT questions FROM ride_assessments WHERE id = ?",
                    (attempt["id"],),
                ).fetchone()[0]
            return [
                question["safe"][0] if question["category"] == "readiness"
                else question["correct_option"]
                for question in json.loads(saved)
            ]

        self.assertEqual(self._request("GET", "/api/rides")[0], 401)
        self.assertEqual(self._request("POST", start, {"kind": "order"}, token)[0], 403)
        status, qualification, _ = self._request(
            "POST", start, {"kind": "qualification"}, token
        )
        self.assertEqual(status, 200)
        self.assertEqual(len(qualification["questions"]), 24)
        self.assertEqual(qualification["min_score"], 16)
        self.assertTrue(all(
            set(q) == {"category", "prompt", "options"} for q in qualification["questions"]
        ))
        answers = answers_for(qualification)
        self.assertEqual(
            self._request("POST", submit, {"id": qualification["id"], "answers": answers}, other_token)[0],
            404,
        )
        self.assertEqual(
            self._request("POST", submit, {"id": qualification["id"], "answers": [True, *answers[1:]]}, token)[0],
            400,
        )
        status, result, _ = self._request(
            "POST", submit, {"id": qualification["id"], "answers": answers}, token
        )
        self.assertEqual(status, 200)
        self.assertTrue(result["passed"])
        self.assertEqual(result["score"], 20)
        self.assertEqual(self._request("POST", start, {"kind": "order"}, other_token)[0], 403)

        _, order, _ = self._request("POST", start, {"kind": "order"}, token)
        self.assertEqual(len(order["questions"]), 7)
        substance_prompt = (
            "Употребляли ли вы недавно алкоголь или принимали лекарства либо другие "
            "вещества, которые могут ухудшить реакцию?"
        )
        self.assertEqual(order["questions"][1]["prompt"], substance_prompt)

        # Exercise an attempt that was opened before the wording changed.
        old_handlebar_prompt = "Как нужно держать руль электросамоката во время движения?"
        handlebar = next(
            question for question in self.server.assessments.traffic
            if question.get("previous_prompt") == old_handlebar_prompt
        )
        self.assertEqual(handlebar["options"][handlebar["correct_option"]], "Держать руль двумя руками")
        with self.server.db.connect() as conn:
            saved = conn.execute(
                "SELECT questions FROM ride_assessments WHERE id = ?", (order["id"],)
            ).fetchone()[0]
            questions = json.loads(saved)
            questions[1]["prompt"] = (
                "Может ли алкоголь, лекарство или другое вещество сейчас ухудшать вашу реакцию?"
            )
            questions[2] = {
                "category": "traffic",
                "prompt": old_handlebar_prompt,
                "options": [
                    "Можно отпустить руль при движении по прямой",
                    "Держаться за руль достаточно только при повороте",
                    "Нужно держаться за руль как минимум одной рукой",
                ],
                "correct_option": 2,
            }
            conn.execute(
                "UPDATE ride_assessments SET questions = ? WHERE id = ?",
                (json.dumps(questions, ensure_ascii=False), order["id"]),
            )

        _, resumed, _ = self._request("POST", start, {"kind": "order"}, token)
        self.assertEqual(resumed["id"], order["id"])
        self.assertEqual(resumed["questions"][1]["prompt"], substance_prompt)
        self.assertEqual(resumed["questions"][2]["prompt"], handlebar["prompt"])
        self.assertEqual(resumed["questions"][2]["options"][2], "Держать руль двумя руками")
        answers = answers_for(order)
        answers[0] = 1  # A flagged readiness answer overrides perfect knowledge.
        _, failed, _ = self._request("POST", submit, {"id": order["id"], "answers": answers}, token)
        self.assertFalse(failed["passed"])
        self.assertFalse(failed["readiness_ok"])
        self.assertEqual(failed["score"], 5)
        self.assertEqual(self._request("POST", submit, {"id": order["id"], "answers": []}, token)[1], failed)
        self.assertEqual(self._request("POST", start, {"kind": "order"}, token)[0], 429)

        reopened = UserDatabase(self.db_path)
        from backend.assessments import RideAssessments
        overview = RideAssessments(reopened).overview(reopened.get_user_by_token(token).id)
        self.assertIsNotNone(overview["qualified_at"])
        self.assertIn(overview["retry_after_seconds"], range(COOLDOWN_SECONDS - 2, COOLDOWN_SECONDS + 1))
        self.assertEqual(overview["history"], [failed])
        with reopened.connect() as conn:
            conn.execute(
                "UPDATE ride_assessments SET completed_at = completed_at - ? WHERE id = ?",
                (COOLDOWN_SECONDS, order["id"]),
            )
            self.assertIsNone(conn.execute(
                "SELECT questions FROM ride_assessments WHERE id = ?", (order["id"],)
            ).fetchone()[0])
        _, next_order, _ = self._request("POST", start, {"kind": "order"}, token)
        _, passed, _ = self._request(
            "POST", submit, {"id": next_order["id"], "answers": answers_for(next_order)}, token
        )
        self.assertTrue(passed["passed"])
        history = self._request("GET", "/api/rides", token=token)[1]["history"]
        self.assertEqual([item["passed"] for item in history], [True, False])
        self.assertEqual(self._request("GET", "/api/rides", token=other_token)[1]["history"], [])

    def test_register_me_logout_and_login_flow(self) -> None:
        status, body, _ = self._request(
            "POST",
            "/api/auth/register",
            {
                "email": "dmitrii@saferide.ru",
                "phone": "+7 (999) 888-77-66",
                "password": "StrongPassword99",
            },
        )
        self.assertEqual(status, 201)
        token = body["token"]
        self.assertIsInstance(token, str)
        self.assertEqual(body["user"]["email"], "dmitrii@saferide.ru")
        self.assertEqual(body["user"]["phone"], "+79998887766")
        self.assertNotIn("password_hash", body["user"])

        # Duplicate registration returns 409
        dup_status, dup_body, _ = self._request(
            "POST",
            "/api/auth/register",
            {
                "email": "dmitrii@saferide.ru",
                "phone": "+79990001122",
                "password": "StrongPassword99",
            },
        )
        self.assertEqual(dup_status, 409)
        self.assertIn("email", dup_body["error"].lower())

        # Fetch current user with token
        me_status, me_body, _ = self._request("GET", "/api/auth/me", token=token)
        self.assertEqual(me_status, 200)
        self.assertEqual(me_body["user"]["email"], "dmitrii@saferide.ru")

        # Logout invalidates token
        logout_status, _, _ = self._request("POST", "/api/auth/logout", {}, token=token)
        self.assertEqual(logout_status, 200)

        expired_status, _, _ = self._request("GET", "/api/auth/me", token=token)
        self.assertEqual(expired_status, 401)

        # Login with phone number
        login_status, login_body, _ = self._request(
            "POST",
            "/api/auth/login",
            {"identifier": "8 999 888 77 66", "password": "StrongPassword99"},
        )
        self.assertEqual(login_status, 200)
        self.assertEqual(login_body["user"]["email"], "dmitrii@saferide.ru")
        self.assertTrue(login_body["token"])

        # Wrong password returns 401
        bad_status, _, _ = self._request(
            "POST",
            "/api/auth/login",
            {"identifier": "dmitrii@saferide.ru", "password": "WrongPassword"},
        )
        self.assertEqual(bad_status, 401)


if __name__ == "__main__":
    unittest.main()
