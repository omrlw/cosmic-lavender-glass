#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail() {
    printf 'repository QA failed: %s\n' "$*" >&2
    exit 1
}

required_files=(
    assets/hero.svg
    assets/palette.svg
    assets/desktop-preview.webp
    assets/dock-preview.webp
    assets/wallpaper-preview.webp
    theme/cosmic-lavender-glass.ron
    wallpapers/cosmic-lavender-glass-5120x1440.png
)

for path in "${required_files[@]}"; do
    [[ -s "$path" ]] || fail "missing or empty file: $path"
done

[[ -x install.sh && -x uninstall.sh ]] ||
    fail 'install and uninstall scripts must be executable'

grep -Fq 'PROJECT_VERSION="1.1.0"' lib/common.sh ||
    fail 'project version is not 1.1.0'
grep -Fq 'releases/download/v1.1.0/' README.md ||
    fail 'README download links do not target v1.1.0'

if grep -Eiq 'checksums|sha256sums|development and verification' README.md; then
    fail 'README still contains verification clutter'
fi

if git grep -InE '/home/|/Users/|OneDrive|omr@|192\.' -- \
    ':!tests/repository.sh'; then
    fail 'tracked files contain a personal absolute path or identifier'
fi

grep -Fq 'expand_to_edges]='\''false'\''' install.sh ||
    fail 'dock edge expansion is not disabled'
grep -Fq 'keep_style_on_maximize]='\''true'\''' install.sh ||
    fail 'dock maximize behavior is not preserved'
grep -Fq 'frosted: Medium' theme/cosmic-lavender-glass.ron ||
    fail 'theme medium blur is missing'
grep -Fq 'frosted_windows: false' theme/cosmic-lavender-glass.ron ||
    fail 'application windows are not opaque'

printf 'repository QA passed\n'
