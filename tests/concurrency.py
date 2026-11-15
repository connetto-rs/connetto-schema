#!/usr/bin/env python3
import argparse
import os
import select
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("container")
parser.add_argument("database")
arguments = parser.parse_args()
command = ["docker", "exec", "-i", arguments.container, "psql", "-X", "-U", "postgres", "-At", "-d", arguments.database]


def execute(statement):
    result = subprocess.run(command + ["-v", "ON_ERROR_STOP=1"], input=statement, text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()


class Session:
    def __init__(self, label):
        self.label = label
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.buffer = b""
        self.sequence = 0

    def request(self, statement):
        self.sequence += 1
        marker = f"{self.label}_{self.sequence}_{uuid.uuid4().hex}"
        deadline = time.monotonic() + 25
        self.process.stdin.write((statement + f"\n\\echo {marker}\n").encode())
        self.process.stdin.flush()
        lines = []
        while True:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                text = line.decode().rstrip("\r")
                if text == marker:
                    return lines
                lines.append(text)
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                raise TimeoutError(marker)
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError(f"{marker} session exited {lines}")
            self.buffer += chunk

    def close(self):
        try:
            self.process.stdin.close()
        except BrokenPipeError:
            pass
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.process.stdout.close()


organization, first_user, second_user, first_team, second_team = (str(uuid.uuid4()) for _ in range(5))
sessions = []
try:
    execute(f"""
SET statement_timeout = '20s';
INSERT INTO users (id) VALUES ('{first_user}'), ('{second_user}');
SET app.user_id = '{first_user}';
SELECT authz_write.create_organization('{organization}');
INSERT INTO memberships (organization_id, user_id, state) VALUES ('{organization}', '{second_user}', 'active');
INSERT INTO teams (id, organization_id) VALUES ('{first_team}', '{organization}'), ('{second_team}', '{organization}');
INSERT INTO grants (resource_id, organization_id, grantee_id, grantee_kind, role)
VALUES ('{organization}', '{organization}', '{second_user}', 'user', 'admin');
""")
    for label in ("first", "second"):
        session = Session(label)
        sessions.append(session)
        lines = session.request(f"\\set ON_ERROR_STOP off\n\\set VERBOSITY verbose\nSET statement_timeout = '20s'; SET lock_timeout = '15s'; SET app.user_id = '{first_user}'; SET ROLE app;\n\\echo SETUP_STATE :SQLSTATE")
        if "SETUP_STATE 00000" not in lines:
            raise RuntimeError(f"{label} setup failed {lines}")

    def race(name, statements, invariant_query, safe_value):
        for session in sessions:
            lines = session.request("BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT count(*) FROM grants;\n\\echo SNAPSHOT_STATE :SQLSTATE")
            if "SNAPSHOT_STATE 00000" not in lines:
                raise RuntimeError(f"FAIL {name} snapshot {lines}")
        refused = 0
        committed = 0
        for session, statement in zip(sessions, statements):
            lines = session.request(statement + "\n\\echo ACTION_STATE :SQLSTATE\nCOMMIT;\n\\echo COMMIT_STATE :SQLSTATE")
            action_state = next(line.split()[1] for line in lines if line.startswith("ACTION_STATE "))
            commit_state = next(line.split()[1] for line in lines if line.startswith("COMMIT_STATE "))
            refused += "25000" in (action_state, commit_state)
            committed += action_state == "00000" and commit_state == "00000"
        observed = execute(invariant_query)
        passed = refused == 2 and committed == 0 and observed == safe_value
        print(f"{'PASS' if passed else 'FAIL'} {name} refused={refused} committed={committed} invariant={observed}", flush=True)
        return passed

    team_result = race("team-cycle", [
        f"INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('{organization}', '{first_team}', '{second_team}');",
        f"INSERT INTO team_parents (organization_id, id, parent_id) VALUES ('{organization}', '{second_team}', '{first_team}');"
    ], f"SELECT count(*) FROM team_parents first_edge JOIN team_parents second_edge ON first_edge.id = second_edge.parent_id AND first_edge.parent_id = second_edge.id WHERE first_edge.organization_id = '{organization}';", "0")
    admin_result = race("last-admin", [
        f"DELETE FROM grants WHERE resource_id = '{organization}' AND grantee_id = '{first_user}';",
        f"DELETE FROM grants WHERE resource_id = '{organization}' AND grantee_id = '{second_user}';"
    ], f"SELECT count(*) FROM grants WHERE resource_id = '{organization}' AND role = 'admin' AND expires_at IS NULL;", "2")
    if not team_result or not admin_result:
        raise SystemExit(1)
finally:
    for session in sessions:
        session.close()
