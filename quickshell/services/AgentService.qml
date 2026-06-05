pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Headless listener for the Claude Code agent bridge. Hosts the Unix socket that
// the hook client (bridge/oai_hook.py) connects to. Maintains per-session status
// and a queue of pending permission requests, and writes Allow/Deny decisions
// back on the held connection. The notch agent UI (later) reads `sessions` /
// `pendingPermissions` and calls allow()/deny(). See bridge/ + NOTES.md §5.
//
// Safety lives on the HOOK side (timeout + fallback). This side just needs to not
// crash on bad input — every parse is guarded; a dropped connection clears its
// pending request so the queue can't wedge.
Singleton {
    id: root

    readonly property string socketPath: {
        const xdg = Quickshell.env("XDG_RUNTIME_DIR");
        return (xdg && xdg.length > 0 ? xdg : "/tmp") + "/openagentisland.sock";
    }
    property bool debug: true

    // session_id → { project, cwd, tool, summary, message, lastEvent, status, ts }
    property var sessions: ({})
    // [{ request_id, session_id, project, cwd, tool, summary, ts }]
    property var pendingPermissions: []
    property var _conns: ({})          // request_id → Socket (held open until decided)
    property var _sessionBypass: ({})  // session_id → true (Bypass: allow ALL tools)
    property var _toolAllow: ({})       // "session|tool" → true (Allow All: this tool)

    // --- derived: what the compact notch shows (most-urgent session) ---
    readonly property var sessionList: {
        const rank = { "permission": 0, "waiting": 1, "working": 2, "running": 3, "idle": 3, "done": 4 };
        const out = [];
        for (const k in root.sessions)
            out.push(Object.assign({ "id": k }, root.sessions[k]));
        out.sort((a, b) => {
            const ra = rank[a.status] ?? 5, rb = rank[b.status] ?? 5;
            if (ra !== rb)
                return ra - rb;
            return (b.ts || 0) - (a.ts || 0); // most recent first within a rank
        });
        return out;
    }
    readonly property int sessionCount: root.sessionList.length
    readonly property string headlineMode: {
        if (root.pendingPermissions.length > 0)
            return "permission";
        let m = "";
        for (let i = 0; i < root.sessionList.length; i++) {
            const s = root.sessionList[i];
            if (s.status === "waiting")
                return "waiting";
            if (s.status === "working" || s.status === "running")
                m = "working";
        }
        // sessions present but resting → show the brand label ("Agent Island")
        if (m === "" && root.sessionList.length > 0)
            return "idle";
        return m;
    }
    readonly property var headlineSession: {
        if (root.pendingPermissions.length > 0) {
            const sid = root.pendingPermissions[0].session_id;
            return root.sessions[sid] ? Object.assign({ "id": sid }, root.sessions[sid]) : null;
        }
        for (let i = 0; i < root.sessionList.length; i++)
            if (root.sessionList[i].status === "waiting")
                return root.sessionList[i];
        for (let i = 0; i < root.sessionList.length; i++)
            if (root.sessionList[i].status === "working")
                return root.sessionList[i];
        return null;
    }
    readonly property bool active: root.headlineMode !== ""

    // no-op so shell.qml can force-instantiate this singleton (→ server goes active)
    function load() {}

    function statusFor(event, prev) {
        switch (event) {
        case "SessionStart": return "idle";
        case "UserPromptSubmit": return "working";
        case "PreToolUse": return "working";
        case "PostToolUse": return "working";
        case "Notification": return "waiting";
        case "Stop": return "done";
        default: return prev || "idle";
        }
    }

    function applyEvent(obj) {
        const sid = obj.session_id || "default";
        const prev = root.sessions[sid] || {};
        const st = statusFor(obj.event, prev.status);
        const next = Object.assign({}, root.sessions);
        next[sid] = {
            "project": obj.project || prev.project || "",
            "cwd": obj.cwd || prev.cwd || "",
            "tool": obj.tool || "",
            "summary": obj.summary || "",
            "message": obj.message || "",
            "lastEvent": obj.event || "",
            "status": st,
            "ts": obj.ts || 0,
            "doneTick": st === "done" ? root._tick : 0,
        };
        root.sessions = next;
    }

    // Prune finished sessions a few seconds after Stop so the notch returns to
    // State 1 (base) when nothing is running. Tick-based to avoid Date.
    property int _tick: 0
    readonly property int _doneLingerTicks: 5
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root._tick++;
            let changed = false;
            const next = Object.assign({}, root.sessions);
            for (const k in next) {
                if (next[k].status === "done" && (root._tick - (next[k].doneTick || 0)) >= root._doneLingerTicks) {
                    delete next[k];
                    changed = true;
                }
            }
            if (changed)
                root.sessions = next;
        }
    }

    function _autoAllowed(sid, tool) {
        return root._sessionBypass[sid] === true || root._toolAllow[sid + "|" + tool] === true;
    }

    function addPermission(obj, conn) {
        const sid = obj.session_id || "";
        const tool = obj.tool || "";
        // Honour an earlier "Allow All" / "Bypass" rule → auto-allow, no UI.
        if (root._autoAllowed(sid, tool)) {
            try {
                conn.write(JSON.stringify({ "type": "permission_decision", "request_id": obj.request_id, "decision": "allow", "reason": "auto-allowed" }) + "\n");
                conn.flush();
            } catch (e) {}
            root.applyEvent({ "session_id": sid, "cwd": obj.cwd, "project": obj.project, "event": "PreToolUse", "tool": tool, "summary": obj.summary });
            return;
        }
        conn.reqId = obj.request_id;
        root._conns[obj.request_id] = conn;
        const list = root.pendingPermissions.slice();
        list.push({
            "request_id": obj.request_id,
            "session_id": sid,
            "project": obj.project || "",
            "cwd": obj.cwd || "",
            "tool": tool,
            "summary": obj.summary || "",
            "preview": obj.preview || null,
            "ts": obj.ts || 0,
        });
        root.pendingPermissions = list;
        const prev = root.sessions[sid || "default"] || {};
        const next = Object.assign({}, root.sessions);
        next[sid || "default"] = Object.assign({}, prev, {
            "project": obj.project || prev.project || "",
            "cwd": obj.cwd || prev.cwd || "",
            "tool": tool,
            "summary": obj.summary || "",
            "status": "permission",
        });
        root.sessions = next;
    }

    function dropPending(reqId) {
        const p = root.pendingPermissions.find(x => x.request_id === reqId);
        delete root._conns[reqId];
        root.pendingPermissions = root.pendingPermissions.filter(x => x.request_id !== reqId);
        // The request is gone (decided or timed out) — don't leave the session
        // stuck showing "permission"; revert it to working.
        if (p) {
            const sid = p.session_id || "default";
            const prev = root.sessions[sid];
            if (prev && prev.status === "permission") {
                const next = Object.assign({}, root.sessions);
                next[sid] = Object.assign({}, prev, { "status": "working" });
                root.sessions = next;
            }
        }
    }

    function decide(reqId, decision, reason) {
        const conn = root._conns[reqId];
        if (conn) {
            try {
                conn.write(JSON.stringify({
                    "type": "permission_decision",
                    "request_id": reqId,
                    "decision": decision,
                    "reason": reason || "",
                }) + "\n");
                conn.flush();
            } catch (e) {}
        }
        dropPending(reqId);
    }
    function _pending(reqId) {
        return root.pendingPermissions.find(p => p.request_id === reqId) || null;
    }
    function deny(reqId) { root.decide(reqId, "deny", "Denied from the island"); }
    function allowOnce(reqId) { root.decide(reqId, "allow", "Allowed once"); }
    function allow(reqId) { root.allowOnce(reqId); }  // alias
    function allowAll(reqId) {
        const p = root._pending(reqId);
        if (p) {
            const m = Object.assign({}, root._toolAllow);
            m[(p.session_id || "") + "|" + (p.tool || "")] = true;
            root._toolAllow = m;
        }
        root.decide(reqId, "allow", "Allow all (this tool, this session)");
    }
    function bypass(reqId) {
        const p = root._pending(reqId);
        if (p) {
            const m = Object.assign({}, root._sessionBypass);
            m[p.session_id || ""] = true;
            root._sessionBypass = m;
        }
        root.decide(reqId, "allow", "Bypass (all tools, this session)");
    }

    function onLine(conn, line) {
        if (!line || line.trim().length === 0)
            return;
        if (root.debug)
            console.log("[agent] recv:", line);
        let obj;
        try {
            obj = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (obj.type === "permission_request" && obj.request_id) {
            root.addPermission(obj, conn);
        } else {
            root.applyEvent(obj);
        }
    }

    // Manual control / test hook: `qs -c openagentisland ipc call agent <fn>`.
    // Acts on the oldest pending permission. Useful for testing the round-trip
    // and as a keyboard-free fallback.
    IpcHandler {
        target: "agent"
        function status(): string {
            return JSON.stringify({
                "sessions": Object.keys(root.sessions).length,
                "pending": root.pendingPermissions.length
            });
        }
        function dump(): string {
            return JSON.stringify({
                "active": root.active,
                "headlineMode": root.headlineMode,
                "sessionCount": root.sessionCount,
                "statuses": root.sessionList.map(s => s.id + ":" + s.status)
            });
        }
        function allowOldest(): string {
            if (root.pendingPermissions.length === 0)
                return "none";
            const r = root.pendingPermissions[0].request_id;
            root.allowOnce(r);
            return "allowOnce " + r;
        }
        function denyOldest(): string {
            if (root.pendingPermissions.length === 0)
                return "none";
            const r = root.pendingPermissions[0].request_id;
            root.deny(r);
            return "deny " + r;
        }
        function allowAllOldest(): string {
            if (root.pendingPermissions.length === 0)
                return "none";
            const r = root.pendingPermissions[0].request_id;
            root.allowAll(r);
            return "allowAll " + r;
        }
        function bypassOldest(): string {
            if (root.pendingPermissions.length === 0)
                return "none";
            const r = root.pendingPermissions[0].request_id;
            root.bypass(r);
            return "bypass " + r;
        }
    }

    SocketServer {
        active: true
        path: root.socketPath
        handler: Component {
            Socket {
                id: conn
                property string reqId: ""
                parser: SplitParser {
                    onRead: line => root.onLine(conn, line)
                }
                onConnectedChanged: {
                    if (!conn.connected && conn.reqId.length > 0) {
                        root.dropPending(conn.reqId);
                        conn.reqId = "";
                    }
                }
            }
        }
    }
}
