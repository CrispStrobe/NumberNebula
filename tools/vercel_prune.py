#!/usr/bin/env python3
"""Keep at most N deployments per Vercel project, team-wide.

Why this exists rather than Vercel's own retention: every project on this team
already carries a `deploymentExpiration` policy, but on the Hobby plan its
`deploymentsToKeep` field is fixed at 10 and the API rejects any attempt to set
it ("should NOT have additional property `deploymentsToKeep`"). Ten retained
deployments across 50 projects, at 30-50 MB for a Flutter web build, is far
past the 10 GB free Deployment Storage allowance. Day-based expiry does not
help either: `deploymentsToKeep` acts as a floor, so shortening expiry still
leaves ten per project.

Three guards, and a deployment is kept if ANY of them applies:
  1. it is among the KEEP newest for its project;
  2. it is the project's current production deployment;
  3. it is pinned by a custom (non-*.vercel.app) domain.

Guard 2 matters more than it looks: some projects' live deployment is older
than the newest three, so a naive "keep newest N" would take the site down.
Guard 3 covers domains that point at one specific deployment rather than
following production.

Env: VERCEL_TOKEN (required), VERCEL_TEAM_ID (required), KEEP (default 3),
DRY_RUN=1 to report without deleting.
"""
import collections
import json
import os
import sys
import time
import urllib.error
import urllib.request

TOKEN = os.environ.get("VERCEL_TOKEN") or sys.exit("VERCEL_TOKEN not set")
TEAM = os.environ.get("VERCEL_TEAM_ID") or sys.exit("VERCEL_TEAM_ID not set")
KEEP = int(os.environ.get("KEEP", "3"))
DRY = os.environ.get("DRY_RUN", "") not in ("", "0", "false")
API = "https://api.vercel.com"


def call(path, method="GET"):
    req = urllib.request.Request(
        API + path, headers={"Authorization": "Bearer " + TOKEN}, method=method
    )
    return json.load(urllib.request.urlopen(req))


def paged(path, key):
    """Walk Vercel's `pagination.next` cursor, which is a timestamp."""
    out, until = [], None
    while True:
        d = call(f"{path}&until={until}" if until else path)
        items = d.get(key, [])
        if not items:
            break
        out += items
        until = d.get("pagination", {}).get("next")
        if not until:
            break
    return out


def main():
    projects = call(f"/v9/projects?teamId={TEAM}&limit=100")["projects"]
    names = {p["id"]: p["name"] for p in projects}
    production = {
        p["id"]: (p.get("targets") or {}).get("production", {}).get("id")
        for p in projects
    }

    pinned = {
        a["deploymentId"]
        for a in paged(f"/v4/aliases?teamId={TEAM}&limit=100", "aliases")
        if a.get("deploymentId") and not a.get("alias", "").endswith(".vercel.app")
    }

    by_project = collections.defaultdict(list)
    for d in paged(f"/v6/deployments?teamId={TEAM}&limit=100", "deployments"):
        by_project[d.get("projectId")].append(d)

    doomed = []
    for pid, deployments in by_project.items():
        deployments.sort(key=lambda d: d.get("createdAt", 0), reverse=True)
        for rank, d in enumerate(deployments):
            if rank < KEEP or d["uid"] == production.get(pid) or d["uid"] in pinned:
                continue
            doomed.append((names.get(pid, pid), d["uid"]))

    total = sum(len(v) for v in by_project.values())
    print(f"{total} deployments, {len(by_project)} projects, KEEP={KEEP}")
    print(f"{'would delete' if DRY else 'deleting'} {len(doomed)}", flush=True)
    if DRY:
        for project, count in collections.Counter(p for p, _ in doomed).most_common():
            print(f"  {count:4d}  {project}")
        return

    deleted = failed = 0
    for i, (project, uid) in enumerate(doomed, 1):
        try:
            call(f"/v13/deployments/{uid}?teamId={TEAM}", "DELETE")
            deleted += 1
        except urllib.error.HTTPError as e:
            # One retry on rate-limit; anything else is reported and skipped so
            # a single bad deployment cannot abort the whole run.
            if e.code == 429:
                time.sleep(20)
                try:
                    call(f"/v13/deployments/{uid}?teamId={TEAM}", "DELETE")
                    deleted += 1
                    continue
                except Exception as retry_err:
                    e = retry_err
            failed += 1
            print(f"  FAIL {project} {uid}: {e}", flush=True)
        if i % 50 == 0:
            print(f"  ...{i}/{len(doomed)}", flush=True)
        time.sleep(0.25)

    print(f"done: deleted={deleted} failed={failed}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
