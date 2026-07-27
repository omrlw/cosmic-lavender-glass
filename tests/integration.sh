#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

pass_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'ok %d - %s\n' "$pass_count" "$1"
}

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "expected file: $1"
}

assert_missing() {
    [[ ! -e "$1" ]] || fail "expected missing path: $1"
}

assert_content() {
    local expected="$1" path="$2"
    [[ -f "$path" ]] || fail "expected file: $path"
    [[ "$(<"$path")" == "$expected" ]] ||
        fail "unexpected content in $path"
}

make_tools() {
    local bin="$1"
    mkdir -p "$bin"

    cp "$TEST_ROOT/stubs/rpm" "$bin/rpm"
    cp "$TEST_ROOT/stubs/cosmic-settings" "$bin/cosmic-settings"
    cp "$TEST_ROOT/stubs/git" "$bin/git"
    cp "$TEST_ROOT/stubs/pgrep" "$bin/pgrep"
    cp "$TEST_ROOT/stubs/pkill" "$bin/pkill"
    chmod +x "$bin"/*
}

new_home() {
    local name="$1" home
    home="$TEST_ROOT/$name/home"
    mkdir -p \
        "$home/.config/cosmic/com.system76.CosmicTheme.Light.Builder/v2" \
        "$home/.config/cosmic/com.system76.CosmicTheme.Light/v2" \
        "$home/.config/cosmic/com.system76.CosmicTheme.Mode/v1" \
        "$home/.config/cosmic/com.system76.CosmicTk/v1" \
        "$home/.config/cosmic/com.system76.CosmicPanel.Dock/v1" \
        "$home/.config/cosmic/com.system76.CosmicBackground/v1"
    printf 'original-builder' > "$home/.config/cosmic/com.system76.CosmicTheme.Light.Builder/v2/accent"
    printf 'original-theme' > "$home/.config/cosmic/com.system76.CosmicTheme.Light/v2/accent"
    printf 'true' > "$home/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
    printf 'true' > "$home/.config/cosmic/com.system76.CosmicTheme.Mode/v1/auto_switch"
    printf '"OriginalIcons"' > "$home/.config/cosmic/com.system76.CosmicTk/v1/icon_theme"
    printf 'true' > "$home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/expand_to_edges"
    printf 'old-wallpaper' > "$home/.config/cosmic/com.system76.CosmicBackground/v1/all"
    printf '%s' "$home"
}

run_install() {
    local home="$1"
    shift
    HOME="$home" \
        XDG_CONFIG_HOME="$home/.config" \
        XDG_DATA_HOME="$home/.local/share" \
        XDG_STATE_HOME="$home/.local/state" \
        XDG_CURRENT_DESKTOP="" \
        PATH="$TEST_ROOT/bin:$PATH" \
        FAKE_MAC_INSTALLER="$TEST_ROOT/stubs/mactahoe-install" \
        "$ROOT/install.sh" "$@"
}

run_uninstall() {
    local home="$1"
    shift
    HOME="$home" \
        XDG_CONFIG_HOME="$home/.config" \
        XDG_DATA_HOME="$home/.local/share" \
        XDG_STATE_HOME="$home/.local/state" \
        XDG_CURRENT_DESKTOP="" \
        PATH="$TEST_ROOT/bin:$PATH" \
        "$ROOT/uninstall.sh" "$@"
}

mkdir -p "$TEST_ROOT/stubs"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ "$1" == "-q" ]]; then printf "1.4.0"; else exit 1; fi' \
    > "$TEST_ROOT/stubs/rpm"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    'if [[ "${1:-}" == "appearance" && "${2:-}" == "import" ]]; then' \
    '  mkdir -p "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Light.Builder/v2"' \
    '  mkdir -p "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Light/v2"' \
    '  printf imported > "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Light.Builder/v2/accent"' \
    '  printf imported > "$XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Light/v2/accent"' \
    '  [[ "${FAIL_IMPORT:-0}" != "1" ]]' \
    'fi' \
    > "$TEST_ROOT/stubs/cosmic-settings"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    '[[ "${FAKE_GIT_FAIL:-0}" != "1" ]] || exit 42' \
    'if [[ "$1" == "clone" ]]; then' \
    '  destination="${@: -1}"' \
    '  mkdir -p "$destination"' \
    '  cp "$FAKE_MAC_INSTALLER" "$destination/install.sh"' \
    '  chmod +x "$destination/install.sh"' \
    'fi' \
    > "$TEST_ROOT/stubs/git"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    'destination=""' \
    'while (($#)); do' \
    '  if [[ "$1" == "-d" ]]; then destination="$2"; shift 2; else shift; fi' \
    'done' \
    'mkdir -p "$destination/MacTahoe"' \
    'printf theme > "$destination/MacTahoe/index.theme"' \
    > "$TEST_ROOT/stubs/mactahoe-install"

printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$TEST_ROOT/stubs/pgrep"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$TEST_ROOT/stubs/pkill"
make_tools "$TEST_ROOT/bin"

fresh_home="$(new_home fresh)"
run_install "$fresh_home" >/dev/null
assert_content 'false' "$fresh_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/expand_to_edges"
assert_content 'true' "$fresh_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/keep_style_on_maximize"
assert_content 'All' "$fresh_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/output"
assert_file "$fresh_home/.local/share/icons/MacTahoe/index.theme"
assert_file "$fresh_home/.local/share/backgrounds/cosmic-lavender-glass/cosmic-lavender-glass-5120x1440.png"
run_uninstall "$fresh_home" >/dev/null
assert_content 'true' "$fresh_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/expand_to_edges"
assert_content 'original-builder' "$fresh_home/.config/cosmic/com.system76.CosmicTheme.Light.Builder/v2/accent"
assert_missing "$fresh_home/.local/share/icons/MacTahoe"
assert_missing "$fresh_home/.local/share/backgrounds/cosmic-lavender-glass"
pass 'fresh install and uninstall restoration'

preinstalled_home="$(new_home preinstalled)"
mkdir -p "$preinstalled_home/.local/share/icons/MacTahoe"
printf personal > "$preinstalled_home/.local/share/icons/MacTahoe/index.theme"
run_install "$preinstalled_home" >/dev/null
run_uninstall "$preinstalled_home" >/dev/null
assert_content 'personal' "$preinstalled_home/.local/share/icons/MacTahoe/index.theme"
pass 'preinstalled MacTahoe is preserved'

skip_home="$(new_home skip)"
FAKE_GIT_FAIL=1 run_install "$skip_home" --skip-icons >/dev/null
assert_content '"OriginalIcons"' "$skip_home/.config/cosmic/com.system76.CosmicTk/v1/icon_theme"
pass 'offline skip-icons installation'

output_home="$(new_home output)"
run_install "$output_home" --skip-icons --output DP-9 >/dev/null
assert_content 'Name("DP-9")' "$output_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/output"
pass 'custom monitor output'

dry_home="$(new_home dry)"
run_install "$dry_home" --skip-icons --dry-run >/dev/null
assert_content 'true' "$dry_home/.config/cosmic/com.system76.CosmicPanel.Dock/v1/expand_to_edges"
assert_missing "$dry_home/.local/state/cosmic-lavender-glass"
pass 'dry run is non-mutating'

failed_home="$(new_home failed)"
if FAIL_IMPORT=1 run_install "$failed_home" --skip-icons >/dev/null 2>&1; then
    fail 'failed import unexpectedly succeeded'
fi
assert_content 'original-builder' "$failed_home/.config/cosmic/com.system76.CosmicTheme.Light.Builder/v2/accent"
assert_content 'old-wallpaper' "$failed_home/.config/cosmic/com.system76.CosmicBackground/v1/all"
assert_missing "$failed_home/.local/share/backgrounds/cosmic-lavender-glass"
pass 'failed dependency rolls back automatically'

printf '1..%d\n' "$pass_count"
