#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAC="$ROOT/cac"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
CAC_DIR="$HOME/.cac"
ENVS_DIR="$CAC_DIR/envs"
VERSIONS_DIR="$CAC_DIR/versions"

make_version() {
    local ver="$1"
    mkdir -p "$VERSIONS_DIR/$ver"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$VERSIONS_DIR/$ver/claude"
    chmod +x "$VERSIONS_DIR/$ver/claude"
}

make_env() {
    local name="$1" ver="$2"
    mkdir -p "$ENVS_DIR/$name/.claude"
    printf '%s\n' "$ver" > "$ENVS_DIR/$name/version"
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $label: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_exists() {
    [[ -e "$1" ]] || { echo "FAIL: expected path to exist: $1" >&2; exit 1; }
}

assert_missing() {
    [[ ! -e "$1" ]] || { echo "FAIL: expected path to be removed: $1" >&2; exit 1; }
}

strip_ansi() {
    perl -pe 's/\e\[[0-9;]*[A-Za-z]//g'
}

mkdir -p "$ENVS_DIR" "$VERSIONS_DIR"
make_version "2.1.100"
make_version "2.1.200"
make_version "2.1.300"
make_env "work" "2.1.100"
make_env "backup" "2.1.100"

UPDATE_OUT="$TMP/cac-update-all.out"
PRUNE_OUT="$TMP/cac-prune.out"

"$CAC" claude update-all 2.1.200 >"$UPDATE_OUT"
assert_eq "2.1.200" "$(tr -d '[:space:]' < "$ENVS_DIR/work/version")" "work version"
assert_eq "2.1.200" "$(tr -d '[:space:]' < "$ENVS_DIR/backup/version")" "backup version"
strip_ansi < "$UPDATE_OUT" | grep -q "Pinned 2 environment(s) -> Claude Code 2.1.200" || {
    echo "FAIL: update-all output did not report pinned env count" >&2
    cat "$UPDATE_OUT" >&2
    exit 1
}

"$CAC" claude prune >"$PRUNE_OUT"
assert_missing "$VERSIONS_DIR/2.1.100"
assert_exists "$VERSIONS_DIR/2.1.200/claude"
assert_missing "$VERSIONS_DIR/2.1.300"
assert_eq "2.1.200" "$(tr -d '[:space:]' < "$VERSIONS_DIR/.latest")" "latest version"
strip_ansi < "$PRUNE_OUT" | grep -q "Uninstalled 2 unused version(s)" || {
    echo "FAIL: prune output did not report removed version count" >&2
    cat "$PRUNE_OUT" >&2
    exit 1
}

echo "PASS: claude bulk version commands"
