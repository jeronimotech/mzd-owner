#!/usr/bin/env python3
"""One-time App Store Connect setup for a new app version — everything the listing and signing tools
don't cover, through the API:

    tool/asc_app_setup.py --version 1.0.0 --dry-run
    tool/asc_app_setup.py --version 1.0.0
    tool/asc_app_setup.py --build 29651234 --compliance-only   # just mark a build's export compliance

- categories (Navigation, secondary Utilities)
- age rating questionnaire: no objectionable content (every frequency NONE, every flag false)
- copyright on the version
- App Review contact + notes (REVIEW_FIRST, REVIEW_LAST, REVIEW_PHONE, REVIEW_EMAIL in the env file)
- price: free (USA base territory)
- export compliance of the build (HTTPS only → not non-exempt encryption)

NOT available in Apple's API, so done on the web once: **App Privacy** (data-collection labels).
Answers are in docs/STORE-LISTING.md → "App Store App Privacy answers".

Reads ASC_KEY_ID / ASC_ISSUER_ID / APP_STORE_ID from the environment (~/.config/mzd-owner/apple.env).
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import asc_listing  # noqa: E402  (same JWT client)

APP_ID = os.environ.get("APP_STORE_ID", "6834614514")
PRIMARY_CATEGORY = "NAVIGATION"
SECONDARY_CATEGORY = "UTILITIES"
COPYRIGHT = "2026 Jeronimo SAS"
REVIEW_NOTES = (
    "The app reads live data from a Bluetooth LE OBD-II adapter plugged into a car. Reviewers won't have one, "
    "so the app starts in Demo mode (Ajustes > Modo demo, on by default) with a simulated drive: the dashboard, "
    "maintenance, diagnostics (sample trouble code P0420) and the drive Live Activity all work without hardware. "
    "The assistant (Asistente tab, or 'Explicar con IA' in Diagnóstico) uses our server and needs internet; "
    "no sign-in is required. This version does not use CarPlay templates. UI language: Spanish."
)


def log(msg: str) -> None:
    print(f"[setup] {msg}", file=sys.stderr)


def version_id(c, version: str) -> str:
    rows = c.all(f"/apps/{APP_ID}/appStoreVersions", {"filter[platform]": "IOS", "limit": 20})
    for v in rows:
        if v["attributes"]["versionString"] == version:
            return v["id"]
    sys.exit(f"no App Store version {version}; run `tool/asc_signing.py appstore --version {version}` first")


def editable_app_info(c) -> str:
    infos = c.all(f"/apps/{APP_ID}/appInfos", {"limit": 10})
    # The editable row is the one not yet live.
    for i in infos:
        if i["attributes"].get("appStoreState") not in ("READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"):
            return i["id"]
    return infos[0]["id"]


def set_categories(c, info_id: str, dry: bool) -> None:
    body = {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": SECONDARY_CATEGORY}}}}}
    if not dry:
        c.request("PATCH", f"/appInfos/{info_id}", body)
    log(f"categories: {PRIMARY_CATEGORY} / {SECONDARY_CATEGORY}")


# Yes/no questions of Apple's 2025 age-rating questionnaire (everything else is a NONE/INFREQUENT/
# FREQUENT frequency). "messagingAndChat" means people messaging each other; an AI assistant isn't that.
AGE_BOOLEANS = {"gambling", "unrestrictedWebAccess", "lootBox", "seventeenPlus", "messagingAndChat",
                "parentalControls", "advertising", "healthOrWellnessTopics", "socialMedia", "ageAssurance",
                "userGeneratedContent", "socialMediaAgeRestricted"}


def set_age_rating(c, info_id: str, dry: bool) -> None:
    decl = c.request("GET", f"/appInfos/{info_id}/ageRatingDeclaration")["data"]
    attrs = {}
    for k, v in decl["attributes"].items():
        if k in ("ageRatingOverride", "ageRatingOverrideV2", "kidsAgeBand", "developerAgeRatingInfoUrl") \
                or "korea" in k.lower() or "grac" in k.lower():
            continue  # overrides and region-specific (Korea GRAC) fields stay untouched
        attrs[k] = False if (isinstance(v, bool) or k in AGE_BOOLEANS) else "NONE"
    if not dry:
        c.request("PATCH", f"/ageRatingDeclarations/{decl['id']}",
                  {"data": {"type": "ageRatingDeclarations", "id": decl["id"], "attributes": attrs}})
    log(f"age rating: {len(attrs)} answers set to none/no")


def set_copyright(c, vid: str, dry: bool) -> None:
    if not dry:
        c.request("PATCH", f"/appStoreVersions/{vid}",
                  {"data": {"type": "appStoreVersions", "id": vid, "attributes": {"copyright": COPYRIGHT}}})
    log(f"copyright: {COPYRIGHT}")


def set_review_detail(c, vid: str, dry: bool) -> None:
    need = ["REVIEW_FIRST", "REVIEW_LAST", "REVIEW_PHONE", "REVIEW_EMAIL"]
    missing = [k for k in need if not os.environ.get(k)]
    if missing:
        log(f"review contact skipped: set {', '.join(missing)} in ~/.config/mzd-owner/apple.env")
        return
    attrs = {"contactFirstName": os.environ["REVIEW_FIRST"], "contactLastName": os.environ["REVIEW_LAST"],
             "contactPhone": os.environ["REVIEW_PHONE"], "contactEmail": os.environ["REVIEW_EMAIL"],
             "demoAccountRequired": False, "notes": REVIEW_NOTES}
    existing = c.request("GET", f"/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if not dry:
        if existing:
            c.request("PATCH", f"/appStoreReviewDetails/{existing['id']}",
                      {"data": {"type": "appStoreReviewDetails", "id": existing["id"], "attributes": attrs}})
        else:
            c.request("POST", "/appStoreReviewDetails",
                      {"data": {"type": "appStoreReviewDetails", "attributes": attrs, "relationships": {
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    log("review contact + notes set")


def set_free_price(c, dry: bool) -> None:
    points = c.request("GET", f"/apps/{APP_ID}/appPricePoints",
                       params={"filter[territory]": "USA", "limit": 200}).get("data", [])
    free = next((p for p in points if float(p["attributes"].get("customerPrice") or 0) == 0.0), None)
    if not free:
        log("price: no free price point found; set it on the web")
        return
    body = {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": APP_ID}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}],
    }
    if not dry:
        c.request("POST", "/appPriceSchedules", body)
    log("price: free")


def set_compliance(c, build_version: str, dry: bool) -> None:
    rows = c.all("/builds", {"filter[app]": APP_ID, "filter[version]": build_version, "limit": 5})
    if not rows:
        log(f"build {build_version} not found (still processing?)")
        return
    b = rows[0]
    if b["attributes"].get("usesNonExemptEncryption") is not None:
        log(f"build {build_version}: export compliance already answered")
        return
    if not dry:
        c.request("PATCH", f"/builds/{b['id']}",
                  {"data": {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}})
    log(f"build {build_version}: export compliance = standard encryption only (exempt)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", help="App Store version, e.g. 1.0.0")
    ap.add_argument("--build", help="CFBundleVersion to mark export compliance on")
    ap.add_argument("--compliance-only", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    c = asc_listing.Client()
    if a.build:
        set_compliance(c, a.build, a.dry_run)
    if a.compliance_only:
        return 0
    if not a.version:
        sys.exit("pass --version")
    info_id = editable_app_info(c)
    vid = version_id(c, a.version)
    set_categories(c, info_id, a.dry_run)
    set_age_rating(c, info_id, a.dry_run)
    set_copyright(c, vid, a.dry_run)
    set_review_detail(c, vid, a.dry_run)
    try:
        set_free_price(c, a.dry_run)
    except SystemExit:
        raise
    except Exception as e:  # pricing has its own rules for apps that already have a schedule
        log(f"price: {e}")
    print("App Privacy labels are web-only: App Store Connect → App Privacy (answers in docs/STORE-LISTING.md)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
