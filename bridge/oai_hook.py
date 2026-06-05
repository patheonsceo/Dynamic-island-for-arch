#!/usr/bin/env python3
"""
OpenAgentIsland — Claude Code hook bridge (client).

Forwards Claude Code hook events to the island over a Unix socket, and (for
PreToolUse) can BLOCK for an Allow/Deny decision from the notch.

=========================  SAFETY CONTRACT  =========================
This script must NEVER hang or break real Claude Code. On ANY problem —
no socket, connect refused, timeout, malformed data, unexpected exception —
it exits 0 with NO stdout. For a `permission` call that means Claude Code
falls back to its NORMAL permission prompt; it never auto-approves and never
hangs. (`PreToolUse` hook exiting 0 with no JSON → normal permission flow;
confirmed against Claude Code hooks docs.)
=====================================================================

Invoked from ~/.claude/settings.json hooks as:
    oai_hook.py status       # fire-and-forget event (SessionStart/UserPromptSubmit/
                             #   PostToolUse/Notification/Stop) — never blocks
    oai_hook.py permission   # PreToolUse: block for notch Allow/Deny, with timeout
"""
import json
import os
import socket
import sys
import time
import uuid

CONNECT_TIMEOUT = 0.25  # connecting to the socket — keep tiny so status never lags
PERMISSION_TIMEOUT = float(os.environ.get("OAI_PERMISSION_TIMEOUT", "20"))


def socket_path():
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    p = os.path.join(base, "openagentisland.sock")
    if os.path.exists(p):
        return p
    return "/tmp/openagentisland.sock"


def read_stdin_json():
    try:
        data = sys.stdin.read()
        return json.loads(data) if data.strip() else {}
    except Exception:
        return {}


def connect(timeout):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(socket_path())
    return s


def summarize(payload):
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    if tool == "Bash":
        return str(ti.get("command", ""))[:300]
    if tool in ("Edit", "Write", "Read", "NotebookEdit"):
        return str(ti.get("file_path", ""))
    try:
        return json.dumps(ti)[:200]
    except Exception:
        return ""


def build_preview(payload):
    """Compact preview of the pending action for the permission card."""
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    if tool == "Bash":
        return {"kind": "bash", "command": str(ti.get("command", ""))[:2000]}
    if tool == "Write":
        content = str(ti.get("content", ti.get("file_text", "")))
        return {"kind": "write", "path": ti.get("file_path", ""),
                "body": "\n".join(content.splitlines()[:24])}
    if tool in ("Edit", "MultiEdit"):
        return {"kind": "edit", "path": ti.get("file_path", ""),
                "old": str(ti.get("old_string", ""))[:1200],
                "new": str(ti.get("new_string", ""))[:1200]}
    if tool == "NotebookEdit":
        return {"kind": "edit", "path": ti.get("notebook_path", ""),
                "new": str(ti.get("new_source", ""))[:1200]}
    return {"kind": "generic", "body": json.dumps(ti)[:1200]}


def base_msg(payload):
    cwd = payload.get("cwd", "") or ""
    prompt = payload.get("prompt") or ""
    message = payload.get("message") or (prompt[:300] if prompt else "")
    return {
        "session_id": payload.get("session_id", ""),
        "cwd": cwd,
        "project": os.path.basename(cwd.rstrip("/")) if cwd else "",
        "event": payload.get("hook_event_name", ""),
        "tool": payload.get("tool_name", ""),
        "summary": summarize(payload),
        "message": message,
        "ts": int(time.time()),
    }


def do_status(payload):
    """Fire-and-forget. Never blocks Claude. Any failure → silent exit 0."""
    msg = base_msg(payload)
    msg["type"] = "event"
    try:
        s = connect(CONNECT_TIMEOUT)
        s.sendall((json.dumps(msg) + "\n").encode())
        s.close()
    except Exception:
        pass
    sys.exit(0)


def do_permission(payload):
    """PreToolUse: ask the notch. On ANY failure/timeout → exit 0, no output →
    Claude falls back to its normal permission prompt. NEVER auto-approve."""
    msg = base_msg(payload)
    msg["type"] = "permission_request"
    msg["request_id"] = uuid.uuid4().hex
    msg["preview"] = build_preview(payload)
    try:
        s = connect(CONNECT_TIMEOUT)
    except Exception:
        sys.exit(0)  # no island listening → normal prompt
    try:
        s.sendall((json.dumps(msg) + "\n").encode())
        s.settimeout(PERMISSION_TIMEOUT)
        buf = b""
        while b"\n" not in buf:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
        s.close()
        line = buf.split(b"\n", 1)[0].decode().strip()
        if not line:
            sys.exit(0)  # island closed without deciding → normal prompt
        resp = json.loads(line)
        decision = resp.get("decision", "")
        if decision == "allow":
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "Approved from the island",
            }}))
            sys.exit(0)
        if decision == "deny":
            reason = resp.get("reason") or "Denied from the island"
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }}))
            sys.exit(0)
        sys.exit(0)  # "ask"/unknown → normal prompt
    except Exception:
        try:
            s.close()
        except Exception:
            pass
        sys.exit(0)  # timeout / error → normal prompt


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    payload = read_stdin_json()
    if mode == "permission":
        do_permission(payload)
    else:
        do_status(payload)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        sys.exit(0)  # absolute backstop — never break Claude Code
