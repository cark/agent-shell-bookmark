#!/usr/bin/env python3
"""Small offline ACP fixture: restore two known sessions and reject all others."""
import json
from pathlib import Path
import sys

log = Path(sys.argv[1])
for line in sys.stdin:
    request = json.loads(line)
    if "id" not in request:
        continue
    method = request["method"]
    with log.open("a") as stream:
        stream.write(json.dumps({"method": method, "params": request.get("params", {})}) + "\n")
    response = {"jsonrpc": "2.0", "id": request["id"]}
    if method == "initialize":
        response["result"] = {"protocolVersion": 1, "agentCapabilities": {"loadSession": True}, "authMethods": []}
    elif method == "session/load" and request["params"]["sessionId"] in ("reading", "planning"):
        session = request["params"]["sessionId"]
        print(json.dumps({"jsonrpc": "2.0", "method": "session/update", "params": {
            "sessionId": session, "update": {"sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "Restored " + session + " conversation."}}}}), flush=True)
        response["result"] = {}
    else:
        response["error"] = {"code": -32602, "message": "Fixture cannot fulfill this request"}
    print(json.dumps(response), flush=True)
