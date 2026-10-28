#!/usr/bin/env python3
"""App Store Connect operations without fastlane or a macOS CI runner.

Used on 2026-10-27/28 when the free-tier GitHub macOS queue stalled: it resubmitted
1.4.10 (14) after a metadata-only rejection and distributed 1.5.44 (60) to
TestFlight. See docs/release-readiness.md ("Local release path").

Credentials come from the environment only (never commit them):
  ASC_KEY_ID      App Store Connect API key id
  ASC_ISSUER_ID   issuer id of that key
  ASC_KEY_PATH    path to the AuthKey_<id>.p8 file
Requires: python3 with `cryptography`.

Commands (run from the repository root):
  status                         versions, review submissions, latest builds
  push-metadata [--write]        diff fastlane/metadata against the editable
                                 App Store version; --write applies it
  resubmit                       resolve the rejected item of the open review
                                 submission and submit it again
  testflight BUILD NOTES_FILE [--macos]
                                 wait for processing, set What to Test, add the
                                 build to every group, submit for Beta App Review
                                 (iOS unless --macos)
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, utils
from cryptography.hazmat.primitives.serialization import load_pem_private_key

BUNDLE_ID = "com.crispstrobe.numbernebula"
BASE = "https://api.appstoreconnect.apple.com"
META = os.path.join("fastlane", "metadata")
EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "WAITING_FOR_REVIEW")


def _token():
    def b64(d):
        return base64.urlsafe_b64encode(d).rstrip(b"=").decode()
    with open(os.environ["ASC_KEY_PATH"], "rb") as f:
        key = load_pem_private_key(f.read(), password=None)
    now = int(time.time())
    head = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    body = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1190,
            "aud": "appstoreconnect-v1"}
    signing = b64(json.dumps(head).encode()) + "." + b64(json.dumps(body).encode())
    r, s = utils.decode_dss_signature(key.sign(signing.encode(), ec.ECDSA(hashes.SHA256())))
    return signing + "." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


TOKEN, TOKEN_AT = None, 0.0


def api(method, path, body=None):
    global TOKEN, TOKEN_AT
    # Tokens live 1190 s; renew well before that, since `testflight` can wait
    # up to an hour for processing.
    if TOKEN is None or time.time() - TOKEN_AT > 900:
        TOKEN, TOKEN_AT = _token(), time.time()
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    if data:
        req.add_header("Content-Type", "application/json")
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            # Dropped connections happen during long polls; retry reads only,
            # so a write is never sent twice.
            if method != "GET" or attempt == 4:
                raise
            print(f"network error ({e}); retrying", flush=True)
            time.sleep(10 * (attempt + 1))


def errors(r):
    """Flatten errors, including meta.associatedErrors: the top-level message
    ("Version is not ready to be submitted yet") hides the real cause, e.g. a
    newly required age-rating answer."""
    out = []
    for e in r.get("errors", []):
        out.append(f"{e.get('code')}: {e.get('detail')}")
        for path, errs in e.get("meta", {}).get("associatedErrors", {}).items():
            out += [f"  {path}: {x.get('code')}: {x.get('detail')}" for x in errs]
    return "\n".join(out)


def app_id():
    _, r = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    return r["data"][0]["id"]


def ios_version(app):
    _, r = api("GET", f"/v1/apps/{app}/appStoreVersions?filter[platform]=IOS&limit=5")
    return next((v for v in r["data"] if v["attributes"]["appStoreState"] in EDITABLE), None)


def meta(locale, name):
    p = os.path.join(META, locale, name + ".txt")
    return open(p, encoding="utf-8").read().strip() if os.path.exists(p) else None


def folder(locale):
    dirs = os.listdir(META)
    return locale if locale in dirs else next(
        (d for d in dirs if d.split("-")[0] == locale.split("-")[0]), None)


def status():
    app = app_id()
    _, v = api("GET", f"/v1/apps/{app}/appStoreVersions?limit=10")
    for x in v["data"]:
        a = x["attributes"]
        print("version", a["platform"], a["versionString"], a["appStoreState"])
    _, s = api("GET", f"/v1/apps/{app}/reviewSubmissions?limit=10")
    for x in s["data"]:
        a = x["attributes"]
        print("submission", x["id"], a["platform"], a["state"], a.get("submittedDate"))
    _, b = api("GET", f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=6"
                      "&include=preReleaseVersion")
    pre = {i["id"]: i["attributes"] for i in b.get("included", [])}
    for x in b["data"]:
        p = pre.get(x["relationships"]["preReleaseVersion"]["data"]["id"], {})
        a = x["attributes"]
        print("build", p.get("platform"), p.get("version"), a["version"],
              a["processingState"], a["uploadedDate"])


def push_metadata(write):
    app = app_id()
    ver = ios_version(app)
    if not ver:
        sys.exit("no editable iOS App Store version")
    vid = ver["id"]
    print("version", ver["attributes"]["versionString"], ver["attributes"]["appStoreState"])

    def patch(kind, id_, attrs):
        s, r = api("PATCH", f"/v1/{kind}/{id_}",
                   {"data": {"type": kind, "id": id_, "attributes": attrs}})
        print(f"  PATCH {kind}: {s}", errors(r) if s >= 300 else "")

    _, infos = api("GET", f"/v1/apps/{app}/appInfos")
    info = next((i for i in infos["data"]
                 if i["attributes"].get("state") != "READY_FOR_DISTRIBUTION"), None)
    if info:
        _, locs = api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")
        for loc in locs["data"]:
            lc = loc["attributes"]["locale"]
            want = meta(folder(lc), "subtitle") if folder(lc) else None
            if want and want != loc["attributes"].get("subtitle"):
                print(f"  {lc} subtitle: {loc['attributes'].get('subtitle')!r} -> {want!r}")
                if write:
                    patch("appInfoLocalizations", loc["id"], {"subtitle": want})

    _, locs = api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    for loc in locs["data"]:
        lc, f = loc["attributes"]["locale"], folder(loc["attributes"]["locale"])
        if not f:
            continue
        attrs = {}
        for name, key in [("description", "description"), ("keywords", "keywords"),
                          ("promotional_text", "promotionalText")]:
            want = meta(f, name)
            if want and want != (loc["attributes"].get(key) or "").strip():
                attrs[key] = want
        print(f"  {lc} changes: {sorted(attrs) or 'none'}")
        if write and attrs:
            patch("appStoreVersionLocalizations", loc["id"], attrs)

    s, rd = api("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    notes = meta("review_information", "notes")
    if s == 200 and notes and (rd["data"]["attributes"].get("notes") or "").strip() != notes:
        print("  review notes differ")
        if write:
            patch("appStoreReviewDetails", rd["data"]["id"], {"notes": notes})
    if not write:
        print("dry run; pass --write to apply")


def resubmit():
    app = app_id()
    _, subs = api("GET", f"/v1/apps/{app}/reviewSubmissions?filter[platform]=IOS"
                         "&filter[state]=UNRESOLVED_ISSUES")
    if not subs["data"]:
        sys.exit("no iOS review submission with unresolved issues")
    sid = subs["data"][0]["id"]
    _, sub = api("GET", f"/v1/reviewSubmissions/{sid}?include=items")
    for item in sub.get("included", []):
        s, r = api("PATCH", f"/v1/reviewSubmissionItems/{item['id']}",
                   {"data": {"type": "reviewSubmissionItems", "id": item["id"],
                             "attributes": {"resolved": True}}})
        print("resolve item:", s)
        if s >= 300:
            sys.exit(errors(r))
    s, r = api("PATCH", f"/v1/reviewSubmissions/{sid}",
               {"data": {"type": "reviewSubmissions", "id": sid,
                         "attributes": {"submitted": True}}})
    print("resubmit:", s, errors(r) if s >= 300 else r["data"]["attributes"])


def testflight(build, notes_file, platform="IOS"):
    app = app_id()
    notes = open(notes_file, encoding="utf-8").read().strip()
    deadline = time.time() + 3600
    while True:
        _, b = api("GET", f"/v1/builds?filter[app]={app}&filter[version]={build}"
                          f"&filter[preReleaseVersion.platform]={platform}")
        state = b["data"][0]["attributes"]["processingState"] if b["data"] else "NOT_VISIBLE"
        print(time.strftime("%H:%M:%S"), platform, "build", build, state, flush=True)
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID") or time.time() > deadline:
            sys.exit(f"build {build}: {state}")
        time.sleep(30)
    bid = b["data"][0]["id"]

    _, locs = api("GET", f"/v1/builds/{bid}/betaBuildLocalizations")
    en = next((x for x in locs["data"] if x["attributes"]["locale"] == "en-US"), None)
    if en:
        s, _ = api("PATCH", f"/v1/betaBuildLocalizations/{en['id']}",
                   {"data": {"type": "betaBuildLocalizations", "id": en["id"],
                             "attributes": {"whatsNew": notes}}})
    else:
        s, _ = api("POST", "/v1/betaBuildLocalizations",
                   {"data": {"type": "betaBuildLocalizations",
                             "attributes": {"locale": "en-US", "whatsNew": notes},
                             "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
    print("what to test:", s)

    _, groups = api("GET", f"/v1/apps/{app}/betaGroups?limit=50")
    for g in groups["data"]:
        a = g["attributes"]
        if a["isInternalGroup"] and a.get("hasAccessToAllBuilds"):
            print("group", a["name"], "already sees all builds")
            continue
        # The group-side endpoint (/v1/betaGroups/{id}/relationships/builds)
        # answered 404 for a freshly processed build; the build side works.
        s, r = api("POST", f"/v1/builds/{bid}/relationships/betaGroups",
                   {"data": [{"type": "betaGroups", "id": g["id"]}]})
        print("group", a["name"], s, errors(r) if s >= 300 else "")

    s, r = api("POST", "/v1/betaAppReviewSubmissions",
               {"data": {"type": "betaAppReviewSubmissions",
                         "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
    print("beta app review:", s, errors(r) if s >= 300 else r["data"]["attributes"])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "status":
        status()
    elif cmd == "push-metadata":
        push_metadata("--write" in sys.argv)
    elif cmd == "resubmit":
        resubmit()
    elif cmd == "testflight" and len(sys.argv) in (4, 5):
        testflight(sys.argv[2], sys.argv[3],
                   "MAC_OS" if "--macos" in sys.argv[4:] else "IOS")
    else:
        sys.exit(__doc__)
