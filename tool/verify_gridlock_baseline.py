"""Reject compile/load failures and retain actual original-API comparison evidence."""
import hashlib
import json
from pathlib import Path
import re
import sys

report = Path("build/gridlock-audit")
log = (report / "baseline.log").read_text()
assert not re.search(r"TimeoutException|timed out after|Compilation failed|Failed to load|compiler exited", log, re.I)
events = [json.loads(line) for line in (report / "baseline.json").read_text().splitlines() if line.strip()]
starts = {e["test"]["id"]: e["test"]["name"] for e in events if e.get("type") == "testStart" and e["test"]["name"].startswith("Gridlock:")}
ends = {e["testID"]: e for e in events if e.get("type") == "testDone"}
assert len(starts) == 37 and all(i in ends and not ends[i].get("skipped") for i in starts)
positives = {
    "Gridlock: actual authored F drag moves one legal cell and saves coherently",
    "Gridlock: actual current Next loads another usable authored puzzle without replaying the win",
}
assert positives <= set(starts.values())
assert all(ends[i]["result"] == "success" for i, name in starts.items() if name in positives)
rows = []
for i, name in starts.items():
    printed = "\n".join(e.get("message", "") for e in events if e.get("type") == "print" and e.get("testID") == i)
    passed = ends[i]["result"] == "success"
    category = "passed" if passed else "assertion" if "TestFailure" in printed else "exception requiring review"
    rows.append({"name": name, "result": ends[i]["result"], "category": category,
                 "errors": [e for e in events if e.get("type") == "error" and e.get("testID") == i]})
failed = sum(row["result"] != "success" for row in rows)
assert int(sys.argv[1]) != 0 and failed >= 11
assert all(row["category"] != "exception requiring review" for row in rows), "Inspect unclassified exceptions before using this comparison"
paths = ["lib/features/games/screens/space_station_gridlock_game.dart", "test/widgets/space_station_gridlock_round_test.dart"]
proof = {"baselineCommit": "32383b40e93f9e84dd7f8a69dc59dcb68f8c6203", "actualCases": len(rows),
         "passed": len(rows) - failed, "assertionNonpasses": failed, "cases": rows,
         "sourceSha256": {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths},
         "baselineScreenSha256": hashlib.sha256((report / "baseline-screen.dart").read_bytes()).hexdigest(),
         "rawArtifacts": {name: hashlib.sha256((report / name).read_bytes()).hexdigest() for name in ["baseline.json", "baseline.log"]},
         "limits": "Original-API comparison only; overlapping first failures, not independent bug count. Loader seams excluded."}
(report / "baseline-proof.json").write_text(json.dumps(proof, indent=2))
print(f"Verified {len(rows)} original-API cases: {len(rows) - failed} passed, {failed} assertion nonpasses; both legal-input positives passed")
