#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="koreader/koreader"
HC_REPO="billiam/hardcoverapp.koplugin"
DEST=".emulator"
APP="$DEST/KOReader.app"
BIN="$APP/Contents/MacOS/koreader"
PLUGINS="$APP/Contents/koreader/plugins"
LINK="$PLUGINS/rebind.koplugin"
HC_CACHE="$PWD/$DEST/hardcoverapp.koplugin"
HC_LINK="$PLUGINS/hardcoverapp.koplugin"
TOKEN_FILE="$DEST/hardcover_token"
BOOKS="$PWD/$DEST/books"
CONSOLE=0
SET_TOKEN=0

for arg in "$@"; do
    case "$arg" in
        --update) rm -rf "$APP" "$HC_CACHE" ;;
        --console) CONSOLE=1 ;;
        --set-token) SET_TOKEN=1 ;;
        -h|--help)
            cat <<'USAGE'
Launch KOReader's macOS emulator with Rebind loaded.

  ./tools/emulator.sh             download the emulator if missing, then launch
  ./tools/emulator.sh --update    re-download the latest KOReader + Hardcover builds
  ./tools/emulator.sh --console   run in the foreground so KOReader's logs stream here
  ./tools/emulator.sh --set-token save a Hardcover API token (prompted, never echoed)

The emulator lives in .emulator/ (gitignored). Rebind is symlinked into it, so edits
to main.lua and rebind/*.lua take effect on the next launch — no rebuild needed.

KOReader opens in .emulator/books/ (seeded with a sample EPUB on first run). Drop
your own EPUBs there to test against — they never touch your real library.

Hardcover lookups: provide an API token and the script installs and configures the
Hardcover plugin for you. The token is read from the HARDCOVER_TOKEN environment
variable, or from .emulator/hardcover_token (chmod 600, and .emulator/ is gitignored).
Get a token at https://hardcover.app/account/api (the part after "Bearer"). The token
is only ever written under .emulator/ — it never enters the repo.
USAGE
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

case "$(uname -m)" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64)        ARCH="x86_64" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

extract_7z() {
    local archive="$1" out="$2"
    if command -v 7zz >/dev/null 2>&1;   then 7zz x -y -o"$out" "$archive" >/dev/null
    elif command -v 7z  >/dev/null 2>&1;  then 7z  x -y -o"$out" "$archive" >/dev/null
    elif command -v 7za >/dev/null 2>&1;  then 7za x -y -o"$out" "$archive" >/dev/null
    elif command -v nix >/dev/null 2>&1;  then nix run nixpkgs#p7zip -- x -y -o"$out" "$archive" >/dev/null
    else
        echo "Need a 7z extractor (7zz, 7z, or nix) to unpack the KOReader build." >&2
        exit 1
    fi
}

install_app() {
    command -v gh >/dev/null 2>&1 || {
        echo "The GitHub CLI (gh) is required to download the emulator build." >&2
        echo "Install it and run 'gh auth login', then retry." >&2
        exit 1
    }

    echo "Finding the latest KOReader macOS build ($ARCH)..."
    local run_id artifact_id staging
    run_id=$(gh run list --repo "$REPO" --workflow macos --status success \
        --limit 1 --json databaseId --jq '.[0].databaseId')
    [ -n "$run_id" ] || { echo "No successful macos build found on $REPO." >&2; exit 1; }

    artifact_id=$(gh api "repos/$REPO/actions/runs/$run_id/artifacts" \
        --jq "[.artifacts[] | select(.name | test(\"$ARCH\"))][0].id")
    [ -n "$artifact_id" ] || { echo "No $ARCH artifact on build $run_id." >&2; exit 1; }

    staging="$DEST/.staging"
    rm -rf "$staging"; mkdir -p "$staging"
    echo "Downloading..."
    gh api "repos/$REPO/actions/artifacts/$artifact_id/zip" > "$staging/koreader.7z"
    echo "Extracting..."
    extract_7z "$staging/koreader.7z" "$staging"
    [ -d "$staging/KOReader.app" ] || { echo "Build did not contain KOReader.app." >&2; exit 1; }
    rm -rf "$APP"
    mv "$staging/KOReader.app" "$APP"
    rm -rf "$staging"
    xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
    echo "Installed to $APP"
}

unzip_to() {
    local archive="$1" out="$2"
    if command -v unzip >/dev/null 2>&1; then unzip -q -o "$archive" -d "$out"
    elif command -v nix >/dev/null 2>&1;  then nix run nixpkgs#unzip -- -q -o "$archive" -d "$out"
    else echo "Need unzip (or nix) to unpack the Hardcover plugin." >&2; exit 1
    fi
}

install_hardcover() {
    command -v gh >/dev/null 2>&1 || {
        echo "The GitHub CLI (gh) is required to download the Hardcover plugin." >&2
        exit 1
    }
    echo "Downloading the Hardcover plugin..."
    local staging
    staging="$DEST/.hc-staging"
    rm -rf "$staging"; mkdir -p "$staging"
    gh release download --repo "$HC_REPO" --pattern "hardcoverapp.koplugin.zip" \
        --dir "$staging" --clobber
    unzip_to "$staging/hardcoverapp.koplugin.zip" "$staging"
    local root
    root="$(dirname "$(find "$staging" -name _meta.lua -maxdepth 3 | head -1)")"
    [ -n "$root" ] && [ -d "$root" ] || { echo "Hardcover release layout unexpected." >&2; exit 1; }
    rm -rf "$HC_CACHE"
    mv "$root" "$HC_CACHE"
    rm -rf "$staging"
}

resolve_token() {
    if [ -n "${HARDCOVER_TOKEN:-}" ]; then
        printf '%s' "$HARDCOVER_TOKEN"; return 0
    fi
    if [ -f "$TOKEN_FILE" ]; then
        tr -d '[:space:]' < "$TOKEN_FILE"; return 0
    fi
    return 0
}

configure_hardcover() {
    local token="$1"
    [ -d "$HC_CACHE" ] || install_hardcover
    printf "return {\n  token = '%s'\n}\n" "$token" > "$HC_CACHE/hardcover_config.lua"
    chmod 600 "$HC_CACHE/hardcover_config.lua"
    ln -sfn "$HC_CACHE" "$HC_LINK"
}

seed_sample_book() {
    local src out
    src="$(mktemp -d)"
    mkdir -p "$src/META-INF" "$src/OEBPS"
    printf 'application/epub+zip' > "$src/mimetype"

    cat > "$src/META-INF/container.xml" <<'XML'
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
XML

    cat > "$src/OEBPS/content.opf" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Pride and Prejudice</dc:title>
    <dc:creator opf:role="aut">Unknown</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="bookid">urn:uuid:rebind-sample-0001</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="chap1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chap1"/>
  </spine>
</package>
XML

    cat > "$src/OEBPS/toc.ncx" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:rebind-sample-0001"/></head>
  <docTitle><text>Pride and Prejudice</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1"><navLabel><text>Chapter 1</text></navLabel><content src="chapter1.xhtml"/></navPoint>
  </navMap>
</ncx>
XML

    cat > "$src/OEBPS/chapter1.xhtml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Pride and Prejudice</title></head>
<body>
<h1>Chapter 1</h1>
<p>It is a truth universally acknowledged, that a single man in possession of a
good fortune, must be in want of a wife.</p>
</body>
</html>
XML

    out="$src/sample.epub"
    ( cd "$src" && zip -X0 -q "$out" mimetype && zip -Xr9Dq "$out" META-INF OEBPS )
    mv "$out" "$BOOKS/Pride and Prejudice.epub"
    rm -rf "$src"
}

mkdir -p "$DEST"

if [ "$SET_TOKEN" -eq 1 ]; then
    printf 'Hardcover API token (input hidden): ' >&2
    read -rs _token; echo >&2
    [ -n "$_token" ] || { echo "No token entered." >&2; exit 1; }
    printf '%s' "$_token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    unset _token
    echo "Saved token to $TOKEN_FILE (gitignored, chmod 600)."
fi

[ -d "$APP" ] || install_app

if [ ! -d "$BOOKS" ]; then
    mkdir -p "$BOOKS"
    seed_sample_book
    echo "Seeded $BOOKS with a sample book to rebind (author is \"Unknown\" — fix it)."
fi

rm -rf "$LINK"; mkdir -p "$LINK"
ln -sfn "$PWD/_meta.lua" "$LINK/_meta.lua"
ln -sfn "$PWD/main.lua"  "$LINK/main.lua"
ln -sfn "$PWD/rebind"    "$LINK/rebind"
echo "Linked Rebind into the emulator."

TOKEN="$(resolve_token)"
if [ -n "$TOKEN" ]; then
    configure_hardcover "$TOKEN"
    echo "Hardcover: configured — lookups are live."
else
    rm -rf "$HC_LINK"
    echo "Hardcover: no token found — Rebind will offer manual editing only."
    echo "  Set one with: ./tools/emulator.sh --set-token   (or export HARDCOVER_TOKEN=...)"
fi
unset TOKEN

pkill -f "$PWD/$BIN" 2>/dev/null || true

if [ "$CONSOLE" -eq 1 ]; then
    echo "Launching KOReader in $BOOKS (Ctrl-C to quit)..."
    exec "$BIN" "$BOOKS"
else
    echo "Launching KOReader in $BOOKS (logs: $DEST/koreader.log)"
    "$BIN" "$BOOKS" >"$DEST/koreader.log" 2>&1 &
    disown
fi
