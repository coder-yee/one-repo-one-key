"""Create stable releases on tag pushes and synchronize the Homebrew tap."""
import base64
import hashlib
import io
import json
import os
import re
import tarfile
import urllib.error
import urllib.request

SOURCE = "coder-yee/one-repo-one-key"
TAP = "coder-yee/homebrew-tap"
FORMULA = f"/repos/{TAP}/contents/Formula/orok.rb"
ARCHIVE_PREFIX = f"https://github.com/{SOURCE}/archive/refs/tags/"


def version(tag):
    if not re.fullmatch(r"v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", tag):
        raise ValueError("Expected a stable version tag such as v0.1.2")
    return tuple(map(int, tag[1:].split(".")))


def request(url, payload=None, token=None, method=None):
    headers = {"User-Agent": "orok-homebrew-sync"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        url, headers=headers,
        data=json.dumps(payload).encode() if payload is not None else None,
        method=method or ("PUT" if payload is not None else "GET"),
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read()


def api(path, payload=None, token=None, method=None):
    return json.loads(request("https://api.github.com" + path, payload, token, method))


def ensure_release(tag, create=False, token=None):
    version(tag)
    if create and not token:
        raise ValueError("GITHUB_TOKEN is required to create a Release")
    try:
        release = api(f"/repos/{SOURCE}/releases/tags/{tag}", token=token)
    except urllib.error.HTTPError as error:
        if error.code != 404 or not create:
            raise
        # Verify that the tag exists; never let the release API create a tag on main.
        api(f"/repos/{SOURCE}/git/ref/tags/{tag}", token=token)
        release = api(f"/repos/{SOURCE}/releases", {
            "tag_name": tag,
            "name": tag,
            "draft": False,
            "prerelease": False,
            "generate_release_notes": True,
            "make_latest": "legacy",
        }, token, method="POST")
        print("Created Release:", release["html_url"])
    if release["draft"] or release["prerelease"] or release["tag_name"] != tag:
        raise ValueError("Only published stable releases can be synchronized")
    return release


def update_formula(text, tag, digest):
    target = version(tag)
    pattern = r'^  url "' + re.escape(ARCHIVE_PREFIX) + r'(v[^"/]+)\.tar\.gz"$'
    matches = list(re.finditer(pattern, text, re.M))
    if len(matches) != 1:
        raise ValueError("Expected exactly one versioned orok source URL")
    current = version(matches[0][1])
    if target < current:
        print("Tap already contains a newer version; skipping.")
        return text
    checksums = list(re.finditer(r'^  sha256 "([a-f0-9]{64})"$', text, re.M))
    if len(checksums) != 1:
        raise ValueError("Expected exactly one SHA-256")
    if target == current:
        if checksums[0][1] != digest:
            raise ValueError("Checksum changed for an existing version; publish a new version")
        return text
    text = re.sub(pattern, f'  url "{ARCHIVE_PREFIX}{tag}.tar.gz"', text, flags=re.M)
    text = re.sub(r'^  sha256 "[a-f0-9]{64}"$', f'  sha256 "{digest}"', text, flags=re.M)
    # A new upstream version starts at revision zero; URL determines its version.
    text = re.sub(r'^  (?:revision \d+|version "[^"]+")\n', '', text, flags=re.M)
    return text


def main():
    tag = os.environ.get("RELEASE_TAG", "")
    version(tag)
    token = os.environ.get("HOMEBREW_TAP_TOKEN", "")
    if not token:
        raise ValueError("Set the HOMEBREW_TAP_TOKEN Actions secret before running")
    ensure_release(tag, create=os.environ.get("CREATE_RELEASE") == "true",
                   token=os.environ.get("GH_TOKEN"))
    archive = request(f"{ARCHIVE_PREFIX}{tag}.tar.gz")
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as package:
        if not any(member.isfile() and member.name.endswith('/orok.sh') for member in package):
            raise ValueError("Release archive does not contain orok.sh")
    digest = hashlib.sha256(archive).hexdigest()
    current = api(FORMULA + "?ref=main")
    original = base64.b64decode(current["content"]).decode()
    updated = update_formula(original, tag, digest)
    if original == updated:
        print("No formula changes needed.")
        return
    result = api(FORMULA, {
        "message": f"chore: update orok to {tag}",
        "content": base64.b64encode(updated.encode()).decode(),
        "sha": current["sha"],
        "branch": "main",
    }, token)
    print("Updated Homebrew formula:", result["commit"]["html_url"])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, urllib.error.URLError, tarfile.TarError) as error:
        raise SystemExit(f"Homebrew sync failed: {error}") from None
