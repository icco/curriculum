#!/usr/bin/env python3
"""Generates game art through the Recraft API.

    tools/recraft.py texture floor_hall [--n 4]
    tools/recraft.py cutout props desk [--n 2]
    tools/recraft.py list

Prompts live in assets/prompts/manifest.json rather than here, so the asset set has
one source of truth. Textures are flat squares that tools/make_tile.gd projects
onto the isometric diamond; cutouts are single objects passed through
removeBackground for an alpha channel. See assets/prompts/recraft.md.

Needs RECRAFT_API_KEY.
"""

import argparse
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

API = "https://external.api.recraft.ai/v1"
ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "prompts" / "manifest.json"
SOURCE = ROOT / "assets" / "source"

# Recraft serves WebP whatever the URL says, and Godot picks its loader from the
# extension, so files must be named for what they actually are.
MAGIC = {b"\x89PNG": ".png", b"RIFF": ".webp", b"\xff\xd8\xff": ".jpg"}

# Blocks belong to the tile atlas: ArtLibrary.block_key() looks them up under
# "tiles/", and the importer only walks tiles, props and entities.
OUT_DIR_FOR = {"props": "props", "entities": "entities", "blocks": "tiles"}


def die(message):
    sys.exit("recraft: " + message)


def load_manifest():
    with open(MANIFEST) as f:
        return json.load(f)


def post(path, body):
    key = os.environ.get("RECRAFT_API_KEY")
    if not key:
        die("RECRAFT_API_KEY is not set")
    request = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        die("%s -> HTTP %d: %s" % (path, e.code, e.read().decode()[:400]))


def download(url, stem):
    """Saves an image, naming it for its real format. Returns the path."""
    # The CDN rejects urllib's default user agent.
    request = urllib.request.Request(url, headers={"User-Agent": "curriculum-assets"})
    with urllib.request.urlopen(request) as response:
        data = response.read()
    suffix = next((s for magic, s in MAGIC.items() if data.startswith(magic)), ".bin")
    path = stem.with_suffix(suffix)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def generate(manifest, prompt, size, n):
    """Returns the URLs of n generated images."""
    result = post(
        "/images/generations",
        {
            "prompt": prompt,
            "model": manifest["model"],
            "size": size,
            "n": n,
            "response_format": "url",
        },
    )
    print("  %d credits" % result["credits"])
    return [item["url"] for item in result["data"]]


def cmd_texture(manifest, args):
    subject = manifest["tiles"].get(args.name)
    if subject is None:
        die("no tile named %r in the manifest" % args.name)
    # A few tiles are one-off features rather than repeating material — there is no
    # such thing as six stair openings across a frame — so they override the rules.
    rules = manifest.get("tile_rules", {}).get(args.name, manifest["texture_rules"])
    prompt = "%s. %s. %s" % (manifest["style"], subject, rules)
    print("texture %s" % args.name)
    urls = generate(manifest, prompt, manifest["texture_size"], args.n)
    for i, url in enumerate(urls):
        stem = SOURCE / "textures" / (args.name if len(urls) == 1 else "%s-%d" % (args.name, i + 1))
        print("  %s" % download(url, stem).relative_to(ROOT))


def cmd_cutout(manifest, args):
    group = manifest.get(args.category)
    if group is None:
        die("no such category %r" % args.category)
    subject = group.get(args.name)
    if subject is None:
        die("no %s named %r in the manifest" % (args.category, args.name))

    facing = ""
    size = manifest["cutout_size"]
    if args.category == "entities":
        facing = " Shown full body standing and facing three-quarters toward the viewer."
        size = manifest["figure_size"]
    prompt = "%s. %s.%s %s" % (manifest["style"], subject, facing, manifest["cutout_rules"])

    print("cutout %s/%s" % (args.category, args.name))
    urls = generate(manifest, prompt, size, args.n)
    for i, url in enumerate(urls):
        name = args.name if len(urls) == 1 else "%s-%d" % (args.name, i + 1)
        cut = post("/images/removeBackground", {"image_url": url})
        print("  %d credits (cutout)" % cut.get("credits", 0))
        stem = SOURCE / OUT_DIR_FOR[args.category] / name
        print("  %s" % download(cut["image"]["url"], stem).relative_to(ROOT))


def cmd_list(manifest, _args):
    for category in ("tiles", "blocks", "props", "entities"):
        names = sorted(manifest.get(category, {}))
        print("%s (%d): %s" % (category, len(names), " ".join(names)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    texture = sub.add_parser("texture", help="generate a flat tile texture")
    texture.add_argument("name")
    texture.add_argument("--n", type=int, default=1, help="how many variants (1-6)")
    texture.set_defaults(func=cmd_texture)

    cutout = sub.add_parser("cutout", help="generate an object and remove its background")
    cutout.add_argument("category", choices=["props", "entities", "blocks"])
    cutout.add_argument("name")
    cutout.add_argument("--n", type=int, default=1, help="how many variants (1-6)")
    cutout.set_defaults(func=cmd_cutout)

    listing = sub.add_parser("list", help="show every asset the manifest defines")
    listing.set_defaults(func=cmd_list)

    args = parser.parse_args()
    args.func(load_manifest(), args)


if __name__ == "__main__":
    main()
