#!/usr/bin/env python3
"""Generates raw illustration variants from Recraft and stages an accepted one per
subject. Reads every prompt from assets/prompts/manifest.json -- there is no prompt
text anywhere else in this pipeline, so a prompt cannot drift from what was generated.

Two-step workflow, deliberately kept separate so a bad generation never costs more
than the API call that made it:

    tools/recraft.py --subject cards/spark          # spend money, get variants
    tools/recraft.py --accept cards/spark 1          # free: pick the keeper

Then tools/import-assets.sh turns every accepted source into a real .png sprite and
imports it (see that script for why the conversion has to happen in Godot).

Hard-won constraints this respects (see assets/prompts/recraft.md for the why):
  - no negative_prompt, no style_id -- unsupported on Recraft's V4 models.
  - colour lives in each subject's own prompt, never in the shared `style` clause,
    because `style` is appended to every subject and would override its colour.
  - Recraft serves WebP regardless of what the URL implies, so every download is
    sniffed by magic bytes rather than trusted by extension.
  - the CDN 403s urllib's default User-Agent.
  - `size` must be one of the model's published strings, not an arbitrary WxH.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "assets" / "prompts" / "manifest.json"
SOURCE_DIR = ROOT / "assets" / "source"
SPEND_LOG = SOURCE_DIR / ".spend.log"

API_URL = "https://external.api.recraft.ai/v1/images/generations"
# Published per-image price for the non-pro V4 raster models this pipeline uses.
# Not authoritative for pro/vector variants -- this pipeline never requests those.
PRICE_PER_IMAGE = 0.035

# Recraft serves WebP no matter what the response implies, so every download is
# identified by its own magic bytes rather than trusted by extension or Content-Type.
MAGIC = [
    (b"\x89PNG\r\n\x1a\n", "png"),
    (b"\xff\xd8\xff", "jpg"),
    (b"RIFF", "webp"),  # confirmed further below: bytes 8-12 must be WEBP
]


def sniff_ext(data: bytes) -> str:
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    for magic, ext in MAGIC:
        if magic != b"RIFF" and data[: len(magic)] == magic:
            return ext
    raise ValueError("downloaded bytes match no known image format (png/jpg/webp)")


def load_manifest() -> dict:
    with open(MANIFEST_PATH) as f:
        return json.load(f)


def find_subjects(manifest: dict, *, subject_id=None, line=None, category=None) -> list[dict]:
    subjects = manifest["subjects"]
    if subject_id:
        matches = [s for s in subjects if s["id"] == subject_id]
        if not matches:
            raise SystemExit(f"no subject with id {subject_id!r} in manifest")
        return matches
    if line:
        matches = [s for s in subjects if s.get("line") == line]
        if not matches:
            raise SystemExit(f"no subjects with line {line!r} in manifest")
        return matches
    if category:
        matches = [s for s in subjects if s.get("category") == category]
        if not matches:
            raise SystemExit(f"no subjects with category {category!r} in manifest")
        return matches
    return subjects


def full_prompt(manifest: dict, subject: dict) -> str:
    return f"{manifest['style']} {subject['prompt']}"


def resolve_size(manifest: dict, subject: dict) -> str:
    size_key = subject.get("size", "square")
    sizes = manifest["sizes"]
    if size_key not in sizes:
        raise SystemExit(f"subject {subject['id']} names unknown size {size_key!r}")
    return sizes[size_key]


def subject_dir(subject: dict) -> Path:
    return SOURCE_DIR / subject["id"]


def existing_variants(subject: dict) -> list[Path]:
    d = subject_dir(subject)
    if not d.is_dir():
        return []
    return sorted(d.glob("v*.png")) + sorted(d.glob("v*.jpg")) + sorted(d.glob("v*.webp"))


def log_spend(subject_id: str, n: int, model: str) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    cost = n * PRICE_PER_IMAGE
    with open(SPEND_LOG, "a") as f:
        f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')}\t{subject_id}\t{model}\tn={n}\tcost={cost:.3f}\n")


def total_spend() -> float:
    if not SPEND_LOG.exists():
        return 0.0
    total = 0.0
    for line in SPEND_LOG.read_text().splitlines():
        parts = line.rsplit("cost=", 1)
        if len(parts) == 2:
            total += float(parts[1])
    return total


def call_recraft(prompt: str, model: str, size: str, n: int, response_format: str) -> list[str]:
    api_key = os.environ.get("RECRAFT_API_KEY")
    if not api_key:
        raise SystemExit("RECRAFT_API_KEY is not set")
    body = json.dumps(
        {
            "prompt": prompt,
            "model": model,
            "size": size,
            "n": n,
            "response_format": response_format,
        }
    ).encode()
    req = urllib.request.Request(
        API_URL,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit(f"Recraft API error {e.code}: {detail}") from None
    return [item["url"] for item in payload["data"]]


def download(url: str) -> bytes:
    # The CDN rejects urllib's default User-Agent with a 403.
    req = urllib.request.Request(url, headers={"User-Agent": "curriculum-assets"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def generate(manifest: dict, subject: dict, n_override: int | None, dry_run: bool) -> None:
    n = n_override or subject.get("n", 2)
    prompt = full_prompt(manifest, subject)
    size = resolve_size(manifest, subject)
    model = manifest["model"]
    print(f"== {subject['id']} (n={n}, size={size}, model={model}) ==")
    print(f"   prompt: {prompt}")
    if dry_run:
        print("   (dry run, no request sent)")
        return
    urls = call_recraft(prompt, model, size, n, manifest.get("response_format", "url"))
    log_spend(subject["id"], len(urls), model)
    out_dir = subject_dir(subject)
    out_dir.mkdir(parents=True, exist_ok=True)
    start = len(existing_variants(subject))
    for i, url in enumerate(urls, start=start + 1):
        data = download(url)
        ext = sniff_ext(data)
        path = out_dir / f"v{i}.{ext}"
        path.write_bytes(data)
        print(f"   wrote {path.relative_to(ROOT)} ({len(data)} bytes, sniffed .{ext})")
    print(f"   running spend: ${total_spend():.2f}")


def accept(subject: dict, variant: int) -> None:
    variants = existing_variants(subject)
    matches = [p for p in variants if p.stem == f"v{variant}"]
    if not matches:
        raise SystemExit(
            f"no v{variant} variant for {subject['id']}; have: "
            + ", ".join(p.name for p in variants)
        )
    src = matches[0]
    dest = subject_dir(subject) / f"accepted{src.suffix}"
    # Remove any previously accepted file of a different extension so a re-accept
    # can't leave two accepted.* files for import_assets.gd to choose between.
    for old in subject_dir(subject).glob("accepted.*"):
        old.unlink()
    dest.write_bytes(src.read_bytes())
    print(f"accepted {src.relative_to(ROOT)} -> {dest.relative_to(ROOT)}")


def list_status(manifest: dict) -> None:
    for subject in manifest["subjects"]:
        variants = existing_variants(subject)
        accepted = list(subject_dir(subject).glob("accepted.*"))
        status = "accepted" if accepted else (f"{len(variants)} variant(s)" if variants else "none")
        print(f"{subject['id']:40s} {status}")
    print(f"\ntotal logged spend: ${total_spend():.2f}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sel = ap.add_mutually_exclusive_group()
    sel.add_argument("--subject", help="generate a single subject id, e.g. cards/spark")
    sel.add_argument("--line", help="generate every level of one card line, e.g. spark")
    sel.add_argument("--category", help="generate every subject in a category, e.g. examiner")
    sel.add_argument("--all", action="store_true", help="generate every subject in the manifest")
    sel.add_argument("--list", action="store_true", help="show accept status and running spend")
    ap.add_argument("--accept", metavar="N", type=int, help="accept variant N for --subject (no API call)")
    ap.add_argument("--n", type=int, help="override the manifest's variant count for this run")
    ap.add_argument("--dry-run", action="store_true", help="print prompts/sizes without calling the API")
    args = ap.parse_args()

    manifest = load_manifest()

    if args.list:
        list_status(manifest)
        return

    if args.accept is not None:
        if not args.subject:
            raise SystemExit("--accept requires --subject")
        subject = find_subjects(manifest, subject_id=args.subject)[0]
        accept(subject, args.accept)
        return

    if not (args.subject or args.line or args.category or args.all):
        raise SystemExit("pass one of --subject/--line/--category/--all/--list, or --accept")

    subjects = find_subjects(manifest, subject_id=args.subject, line=args.line, category=args.category)
    for subject in subjects:
        generate(manifest, subject, args.n, args.dry_run)


if __name__ == "__main__":
    main()
