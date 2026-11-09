#!/usr/bin/env bash
set -euo pipefail
CALLER_PWD="$PWD"
cd "$(dirname "$0")/.."

REPO="koreader/koreader"
HC_REPO="billiam/hardcoverapp.koplugin"
DEST=".emulator"
OS="$(uname -s)"
case "$OS" in
    Darwin)
        APP="$DEST/KOReader.app"
        BIN="$APP/Contents/MacOS/koreader"
        KO_ROOT="$APP/Contents/koreader" ;;
    Linux)
        APP="$DEST/koreader-linux"
        BIN="$APP/bin/koreader"
        KO_ROOT="$APP/lib/koreader" ;;
    *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac
PLUGINS="$KO_ROOT/plugins"
LINK="$PLUGINS/rebind.koplugin"
HARNESS_LINK="$PLUGINS/rebindharness.koplugin"
HC_CACHE="$PWD/$DEST/hardcoverapp.koplugin"
HC_LINK="$PLUGINS/hardcoverapp.koplugin"
TOKEN_FILE="$DEST/hardcover_token"
BOOKS="$PWD/$DEST/books"
SPOOL="$PWD/$DEST/spool"
PID_FILE="$PWD/$DEST/koreader.pid"
HEADLESS_HOME="$PWD/$DEST/headless-home"
SCREEN_W=1072
SCREEN_H=1448
SCREEN_DPI=300
START_TIMEOUT=120
REQUEST_TIMEOUT=60
STOP_TIMEOUT=15
SUBCOMMAND="start"
HEADLESS=0
CONSOLE=0
SET_TOKEN=0
UPDATE=0
SHOT_PATH=""

usage() {
    cat <<'USAGE'
Run KOReader's emulator with Rebind loaded, on macOS or Linux, with or without a window.

  ./tools/emulator.sh [start]             download the emulator if missing, then launch it in a window
  ./tools/emulator.sh start --headless    launch with no window on a fixed 1072x1448, 300 dpi screen
  ./tools/emulator.sh screenshot <path>   write a PNG of what KOReader shows, once the screen has settled
  ./tools/emulator.sh stop                exit KOReader cleanly

Options for start:
  --headless    no window (SDL3 offscreen driver); returns once the harness is ready
  --update      re-download the latest KOReader + Hardcover builds
  --console     run in the foreground so KOReader's logs stream here
  --set-token   save a Hardcover API token (prompted, never echoed)

The emulator lives in .emulator/ (gitignored). It is the KOReader master build from the
latest successful CI run, downloaded with an authenticated gh: the macOS build on macOS,
the linux-<arch> tarball on Linux. Rebind is symlinked into it, so edits to main.lua and
rebind/*.lua take effect on the next start - no rebuild needed. The dev-only harness
(tools/harness.koplugin) is linked in too and is never packaged with Rebind.

KOReader opens in .emulator/books/ (seeded with a sample EPUB on first run). Drop
your own EPUBs there to test against - they never touch your real library. Headless runs
keep their KOReader settings in .emulator/headless-home/ and start from a clean one each time.

screenshot is taken from KOReader's own framebuffer, so nothing outside KOReader can
appear in it. It returns only after the screen has settled. The command and KOReader talk
through the private spool directory .emulator/spool/.

Hardcover lookups: provide an API token and the script installs and configures the
Hardcover plugin for you. The token is read from the HARDCOVER_TOKEN environment
variable, or from .emulator/hardcover_token (chmod 600, and .emulator/ is gitignored).
Get a token at https://hardcover.app/account/api (the part after "Bearer"). The token
is only ever written under .emulator/ - it never enters the repo. Without a token,
Rebind offers manual editing only.
USAGE
}

case "${1:-}" in
    start|stop|screenshot) SUBCOMMAND="$1"; shift ;;
esac

for arg in "$@"; do
    case "$arg" in
        --update) UPDATE=1 ;;
        --console) CONSOLE=1 ;;
        --set-token) SET_TOKEN=1 ;;
        --headless) HEADLESS=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $arg" >&2; exit 1 ;;
        *)
            if [ "$SUBCOMMAND" = "screenshot" ] && [ -z "$SHOT_PATH" ]; then
                SHOT_PATH="$arg"
            else
                echo "Unknown argument: $arg" >&2; exit 1
            fi ;;
    esac
done

case "$(uname -m)" in
    arm64|aarch64) ARCH="arm64"; SYSTEM_LOADER="/lib/ld-linux-aarch64.so.1" ;;
    x86_64)        ARCH="x86_64"; SYSTEM_LOADER="/lib64/ld-linux-x86-64.so.2" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

missing_tool() {
    echo "Need $1 to $2." >&2
    echo "Enter the devshell with 'nix develop' (or 'direnv allow'), or install it yourself." >&2
    exit 1
}

first_command() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 && { printf '%s' "$cmd"; return 0; }
    done
    return 1
}

install_app() {
    command -v gh >/dev/null 2>&1 || {
        echo "The GitHub CLI (gh) is required to download the emulator build." >&2
        echo "Install it and run 'gh auth login', then retry." >&2
        exit 1
    }
    local extractor name_pattern
    if [ "$OS" = "Darwin" ]; then
        extractor="$(first_command 7zz 7z 7za)" ||
            missing_tool "a 7z extractor (7zz, 7z or 7za)" "unpack the KOReader build"
        name_pattern="^koreader-macos-.*-$ARCH-"
    else
        command -v xz >/dev/null 2>&1 || missing_tool "xz" "unpack the KOReader build"
        extractor="tar"
        name_pattern="^koreader-linux-$ARCH-"
    fi

    echo "Finding the latest KOReader build ($OS $ARCH)..."
    local run_id artifact_id staging
    run_id=$(gh run list --repo "$REPO" --workflow release.yml --branch master \
        --status success --limit 1 --json databaseId --jq '.[0].databaseId')
    [ -n "$run_id" ] || { echo "No successful release build found on $REPO." >&2; exit 1; }

    artifact_id=$(gh api "repos/$REPO/actions/runs/$run_id/artifacts" \
        --jq "[.artifacts[] | select(.name | test(\"$name_pattern\"))][0].id")
    [ -n "$artifact_id" ] || { echo "No $ARCH artifact on build $run_id." >&2; exit 1; }

    staging="$DEST/.staging"
    rm -rf "$staging"; mkdir -p "$staging/out"
    echo "Downloading..."
    gh api "repos/$REPO/actions/artifacts/$artifact_id/zip" > "$staging/koreader.pkg"
    echo "Extracting..."
    if [ "$OS" = "Darwin" ]; then
        "$extractor" x -y -o"$staging/out" "$staging/koreader.pkg" >/dev/null
        [ -d "$staging/out/KOReader.app" ] || { echo "Build did not contain KOReader.app." >&2; exit 1; }
        rm -rf "$APP"
        mv "$staging/out/KOReader.app" "$APP"
        xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
    else
        tar -xJf "$staging/koreader.pkg" -C "$staging/out"
        [ -x "$staging/out/bin/koreader" ] || { echo "Build did not contain bin/koreader." >&2; exit 1; }
        rm -rf "$APP"
        mv "$staging/out" "$APP"
    fi
    rm -rf "$staging"
    echo "Installed to $APP"
}

install_hardcover() {
    command -v gh >/dev/null 2>&1 || {
        echo "The GitHub CLI (gh) is required to download the Hardcover plugin." >&2
        exit 1
    }
    command -v unzip >/dev/null 2>&1 || missing_tool "unzip" "unpack the Hardcover plugin"
    echo "Downloading the Hardcover plugin..."
    local staging
    staging="$DEST/.hc-staging"
    rm -rf "$staging"; mkdir -p "$staging"
    gh release download --repo "$HC_REPO" --pattern "hardcoverapp.koplugin.zip" \
        --dir "$staging" --clobber
    unzip -q -o "$staging/hardcoverapp.koplugin.zip" -d "$staging"
    local root
    root="$(dirname "$(find "$staging" -name _meta.lua -maxdepth 3 | head -1)")"
    [ -n "$root" ] && [ -d "$root" ] || { echo "Hardcover release layout unexpected." >&2; exit 1; }
    rm -rf "$HC_CACHE"
    mv "$root" "$HC_CACHE"
    rm -rf "$staging"
}

# The Hardcover plugin runs every API call inside Trapper:dismissableRunInSubprocess.
# That fork()s, and on macOS the child segfaults the first time it touches Apple's
# Network.framework (SIGSEGV in nwlog_legacy_init -> os_log_create), because that
# framework is not fork-safe. The parent survives, gets nothing back, and every lookup
# silently reports "No match found". Run the query in-process instead, which the
# emulator can do safely. Emulator-only: the plugin on a real device is untouched.
patch_hardcover_fork() {
    local api="$HC_CACHE/hardcover/lib/hardcover_api.lua"
    [ -f "$api" ] || return 0
    grep -q "dismissableRunInSubprocess" "$api" || return 0
    command -v python3 >/dev/null 2>&1 || missing_tool "python3" "patch the Hardcover plugin"
    python3 - "$api" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
patched = re.sub(
    r"completed, content = Trapper:dismissableRunInSubprocess\(function\(\)\s*\n"
    r"\s*return self:_query\(query, parameters\)\s*\n"
    r"\s*end, true, true\)",
    "completed, content = true, self:_query(query, parameters)",
    src,
)
if patched == src:
    sys.stderr.write("emulator.sh: could not patch the Hardcover fork call; "
                     "lookups may crash on macOS.\n")
    sys.exit(0)
open(path, "w", encoding="utf-8").write(patched)
print("Patched the Hardcover plugin to query in-process (macOS fork safety).")
PY
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
    case "$token" in
        *[!A-Za-z0-9._~+/=-]*) fail "The Hardcover token contains characters a token never has; check HARDCOVER_TOKEN or $TOKEN_FILE." ;;
    esac
    [ -d "$HC_CACHE" ] || install_hardcover
    if [ "$OS" = "Darwin" ]; then patch_hardcover_fork; fi
    ( umask 077; printf "return {\n  token = '%s'\n}\n" "$token" > "$HC_CACHE/hardcover_config.lua" )
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

fail() {
    echo "$*" >&2
    exit 1
}

is_running() {
    local pid state
    [ -f "$PID_FILE" ] || return 1
    pid="$(cat "$PID_FILE")"
    state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d ' ')" || return 1
    [ -n "$state" ] && [ "${state#Z}" = "$state" ] || return 1
    ps -o command= -p "$pid" 2>/dev/null | grep -qF -- "$BOOKS"
}

request() {
    local id="$1"
    shift
    printf '%s\n' "$@" > "$SPOOL/$id.cmd.tmp"
    mv "$SPOOL/$id.cmd.tmp" "$SPOOL/$id.cmd"
    for _ in $(seq 1 $((REQUEST_TIMEOUT * 5))); do
        [ -f "$SPOOL/$id.res" ] && return 0
        is_running || { echo "KOReader exited before it answered." >&2; return 1; }
        sleep 0.2
    done
    echo "KOReader did not answer within ${REQUEST_TIMEOUT}s." >&2
    return 1
}

request_result() {
    local id="$1" status message
    status="$(sed -n 1p "$SPOOL/$id.res")"
    message="$(sed -n 2p "$SPOOL/$id.res")"
    rm -f "$SPOOL/$id.res"
    [ "$status" = "ok" ] && return 0
    echo "KOReader: $message" >&2
    return 1
}

new_request_id() {
    printf '%s-%s' "$(date +%s)" "$$"
}

require_running() {
    is_running && [ -f "$SPOOL/ready" ] ||
        fail "KOReader is not running. Start it with: ./tools/emulator.sh start --headless"
}

stop_running() {
    local pid id
    if ! is_running; then
        rm -f "$PID_FILE"
        return 1
    fi
    pid="$(cat "$PID_FILE")"
    if [ -f "$SPOOL/ready" ]; then
        id="$(new_request_id)"
        if request "$id" quit; then request_result "$id" || true; fi
    fi
    for _ in $(seq 1 $((STOP_TIMEOUT * 5))); do
        is_running || break
        sleep 0.2
    done
    if is_running; then
        echo "KOReader did not exit on its own; terminating it." >&2
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
        sleep 2
        pkill -9 -P "$pid" 2>/dev/null || true
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    return 0
}

cmd_stop() {
    if stop_running; then
        echo "KOReader stopped."
    else
        echo "KOReader is not running."
    fi
}

cmd_screenshot() {
    local id
    [ -n "$SHOT_PATH" ] || fail "Usage: ./tools/emulator.sh screenshot <path>"
    require_running
    case "$SHOT_PATH" in
        /*) ;;
        *) SHOT_PATH="$CALLER_PWD/$SHOT_PATH" ;;
    esac
    [ -d "$(dirname "$SHOT_PATH")" ] || fail "The directory for $SHOT_PATH does not exist."
    id="$(new_request_id)"
    request "$id" screenshot || exit 1
    request_result "$id" || exit 1
    mv -f "$SPOOL/$id.png" "$SHOT_PATH"
    echo "Saved $SHOT_PATH"
}

link_plugins() {
    rm -rf "$LINK"; mkdir -p "$LINK"
    ln -sfn "$PWD/_meta.lua" "$LINK/_meta.lua"
    ln -sfn "$PWD/main.lua"  "$LINK/main.lua"
    ln -sfn "$PWD/rebind"    "$LINK/rebind"
    echo "Linked Rebind into the emulator."

    rm -rf "$HARNESS_LINK"; mkdir -p "$HARNESS_LINK"
    ln -sfn "$PWD/tools/harness.koplugin/_meta.lua" "$HARNESS_LINK/_meta.lua"
    ln -sfn "$PWD/tools/harness.koplugin/main.lua"  "$HARNESS_LINK/main.lua"
    echo "Linked the emulator harness in."
}

setup_hardcover() {
    local token
    token="$(resolve_token)"
    if [ -n "$token" ]; then
        configure_hardcover "$token"
        echo "Hardcover: configured - lookups are live."
    else
        rm -rf "$HC_LINK"
        echo "Hardcover: no token found - Rebind will offer manual editing only."
        echo "  Set one with: ./tools/emulator.sh --set-token   (or export HARDCOVER_TOKEN=...)"
    fi
}

use_devshell_loader() {
    [ "$OS" = "Linux" ] && [ -n "${REBIND_EMULATOR_LOADER:-}" ] || return 1
    [ "$HEADLESS" -eq 1 ] || [ ! -e "$SYSTEM_LOADER" ]
}

launch() {
    local workdir="$PWD" log="$PWD/$DEST/koreader.log"
    local -a env_vars=("REBIND_HARNESS_SPOOL=$SPOOL") command=("$PWD/$BIN" "$BOOKS")

    if [ "$HEADLESS" -eq 1 ]; then
        rm -rf "$HEADLESS_HOME"; mkdir -p "$HEADLESS_HOME"
        printf 'return {\n  ["color_rendering"] = true,\n}\n' > "$HEADLESS_HOME/settings.reader.lua"
        env_vars+=(
            "SDL_VIDEODRIVER=offscreen"
            "EMULATE_READER_W=$SCREEN_W"
            "EMULATE_READER_H=$SCREEN_H"
            "EMULATE_READER_DPI=$SCREEN_DPI"
            "KO_HOME=$HEADLESS_HOME"
        )
    fi

    if use_devshell_loader; then
        workdir="$PWD/$KO_ROOT"
        env_vars+=(
            "LD_LIBRARY_PATH=$workdir/libs${REBIND_EMULATOR_LIBS:+:$REBIND_EMULATOR_LIBS}"
            "LC_ALL=C.UTF-8"
        )
        command=("$REBIND_EMULATOR_LOADER" ./luajit reader.lua "$BOOKS")
    fi

    if [ "$CONSOLE" -eq 1 ]; then
        echo "Launching KOReader in $BOOKS (Ctrl-C to quit)..."
        cd "$workdir"
        exec env "${env_vars[@]}" "${command[@]}"
    fi

    echo "Launching KOReader in $BOOKS (logs: $DEST/koreader.log)"
    (
        cd "$workdir"
        env "${env_vars[@]}" "${command[@]}" >"$log" 2>&1 </dev/null &
        echo $! > "$PID_FILE"
    )

    for _ in $(seq 1 $((START_TIMEOUT * 5))); do
        [ -f "$SPOOL/ready" ] && { echo "KOReader is ready."; return 0; }
        if ! is_running; then
            echo "KOReader exited during startup. Last lines of $DEST/koreader.log:" >&2
            tail -n 20 "$log" >&2
            exit 1
        fi
        sleep 0.2
    done
    echo "KOReader was not ready after ${START_TIMEOUT}s. Last lines of $DEST/koreader.log:" >&2
    tail -n 20 "$log" >&2
    exit 1
}

cmd_start() {
    stop_running || true
    pkill -f "$PWD/$BIN" 2>/dev/null || true
    if [ "$UPDATE" -eq 1 ]; then rm -rf "$APP" "$HC_CACHE"; fi

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
        echo "Seeded $BOOKS with a sample book to rebind (author is \"Unknown\" - fix it)."
    fi

    link_plugins
    setup_hardcover

    rm -rf "$SPOOL"; mkdir -p "$SPOOL"; chmod 700 "$SPOOL"
    launch
}

mkdir -p "$DEST"

case "$SUBCOMMAND" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    screenshot) cmd_screenshot ;;
esac
