#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT="all"
SKIP_ICONS=false
DRY_RUN=false
BACKUP_READY=false
INSTALL_FINISHED=false

usage() {
    printf '%s\n' \
        "Usage: ./install.sh [--output all|NAME] [--skip-icons] [--dry-run]" \
        '' \
        '  --output all|NAME  Put the dock on all displays (default) or one output.' \
        '  --skip-icons       Keep the current icon theme; do not install MacTahoe.' \
        '  --dry-run          Print the planned changes without writing anything.'
}

while (($#)); do
    case "$1" in
        --output)
            (($# >= 2)) || die '--output requires a value'
            OUTPUT="$2"
            shift 2
            ;;
        --skip-icons)
            SKIP_ICONS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

if [[ "$OUTPUT" != "all" && ! "$OUTPUT" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    die 'output names may contain only letters, digits, dot, underscore, colon, and dash'
fi

require_home

detect_cosmic_version() {
    local version=""
    if command -v rpm >/dev/null 2>&1; then
        version="$(rpm -q --qf '%{VERSION}' cosmic-settings 2>/dev/null || true)"
    elif command -v dpkg-query >/dev/null 2>&1; then
        version="$(dpkg-query -W -f='${Version}' cosmic-settings 2>/dev/null || true)"
        version="${version%%-*}"
    fi
    if [[ -z "$version" ]] && command -v cosmic-settings >/dev/null 2>&1; then
        version="$(cosmic-settings --version 2>/dev/null | sed -n 's/.* \([0-9][0-9.]*\)$/\1/p' | tail -n 1)"
    fi
    [[ -n "$version" ]] || die 'COSMIC Settings is required'
    if [[ "$(printf '%s\n%s\n' '1.4.0' "$version" | sort -V | head -n 1)" != "1.4.0" ]]; then
        die "COSMIC 1.4.0 or newer is required (found $version)"
    fi
    log "COSMIC $version detected"
}

write_value() {
    local path="$1" value="$2"
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '[dry-run] write %q to %q\n' "$value" "$path"
        return
    fi
    mkdir -p "$(dirname "$path")"
    printf '%s' "$value" > "$path.tmp.$$"
    mv -f "$path.tmp.$$" "$path"
}

ron_escape() {
    local escaped="$1"
    escaped="${escaped//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    printf '%s' "$escaped"
}

record_new_icon_dirs() {
    local before_file="$1" path
    [[ "$DRY_RUN" == "false" ]] || return 0
    : > "$BACKUP_DIR/installed-icons"
    while IFS= read -r path; do
        if ! grep -Fxq -- "$path" "$before_file"; then
            printf '%s\n' "$path" >> "$BACKUP_DIR/installed-icons"
        fi
    done < <(find "$ICONS_HOME" -mindepth 1 -maxdepth 1 -type d -name 'MacTahoe*' -print 2>/dev/null | LC_ALL=C sort)
}

rollback() {
    local status=$?
    if [[ "$status" -ne 0 && "$BACKUP_READY" == "true" && "$INSTALL_FINISHED" == "false" ]]; then
        printf 'Installation failed; restoring backup %s...\n' "$BACKUP_ID" >&2
        set +e
        record_new_icon_dirs "${ICONS_BEFORE_FILE:-/dev/null}"
        restore_backup_files "$BACKUP_DIR"
        remove_installed_icons "$BACKUP_DIR"
        restore_project_wallpaper "$BACKUP_DIR"
        set -e
    fi
    exit "$status"
}
trap rollback EXIT

detect_cosmic_version
command -v cosmic-settings >/dev/null 2>&1 || die 'cosmic-settings is required'
[[ -r "$SCRIPT_DIR/theme/cosmic-lavender-glass.ron" ]] || die 'theme file is missing'
[[ -r "$SCRIPT_DIR/wallpapers/cosmic-lavender-glass-5120x1440.png" ]] || die 'wallpaper file is missing'

if [[ "$SKIP_ICONS" == "false" && ! -f "$ICONS_HOME/MacTahoe/index.theme" ]]; then
    command -v git >/dev/null 2>&1 || die 'git is required to install MacTahoe (or use --skip-icons)'
fi

create_backup
BACKUP_READY=true

ICONS_BEFORE_FILE="${TMPDIR:-/tmp}/$PROJECT_ID-icons-before-$$"
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$ICONS_HOME"
    find "$ICONS_HOME" -mindepth 1 -maxdepth 1 -type d -name 'MacTahoe*' -print 2>/dev/null |
        LC_ALL=C sort > "$ICONS_BEFORE_FILE"
fi

if [[ "$SKIP_ICONS" == "true" ]]; then
    log 'Skipping MacTahoe icons'
elif [[ -f "$ICONS_HOME/MacTahoe/index.theme" ]]; then
    log 'Using the existing MacTahoe installation'
else
    temp_checkout="${TMPDIR:-/tmp}/$PROJECT_ID-mactahoe-$$"
    run rm -rf -- "$temp_checkout"
    run git clone --filter=blob:none --no-checkout "$MAC_TAHOE_REPO" "$temp_checkout"
    run git -C "$temp_checkout" checkout --detach "$MAC_TAHOE_COMMIT"
    run "$temp_checkout/install.sh" -d "$ICONS_HOME" -t blue
    record_new_icon_dirs "$ICONS_BEFORE_FILE"
    run rm -rf -- "$temp_checkout"
    log "Installed MacTahoe at $MAC_TAHOE_COMMIT"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log "Would import $SCRIPT_DIR/theme/cosmic-lavender-glass.ron"
else
    cosmic-settings appearance import "$SCRIPT_DIR/theme/cosmic-lavender-glass.ron"
fi

if [[ "$SKIP_ICONS" == "false" ]]; then
    write_value "$COSMIC_CONFIG_HOME/com.system76.CosmicTk/v1/icon_theme" '"MacTahoe"'
fi
write_value "$COSMIC_CONFIG_HOME/com.system76.CosmicTheme.Mode/v1/is_dark" 'false'
write_value "$COSMIC_CONFIG_HOME/com.system76.CosmicTheme.Mode/v1/auto_switch" 'false'

run mkdir -p "$WALLPAPER_HOME"
run cp -f "$SCRIPT_DIR/wallpapers/cosmic-lavender-glass-5120x1440.png" \
    "$WALLPAPER_HOME/cosmic-lavender-glass-5120x1440.png"

wallpaper_path="$WALLPAPER_HOME/cosmic-lavender-glass-5120x1440.png"
wallpaper_path_ron="$(ron_escape "$wallpaper_path")"
wallpaper_config="(
    output: \"all\",
    source: Path(\"$wallpaper_path_ron\"),
    filter_by_theme: false,
    rotation_frequency: 300,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)"
write_value "$COSMIC_CONFIG_HOME/com.system76.CosmicBackground/v1/all" "$wallpaper_config"

dock_dir="$COSMIC_CONFIG_HOME/com.system76.CosmicPanel.Dock/v1"
if [[ "$OUTPUT" == "all" ]]; then
    dock_output='All'
else
    dock_output="Name(\"$OUTPUT\")"
fi

declare -A dock_values=(
    [anchor]='Bottom'
    [anchor_gap]='true'
    [autohide]='Never'
    [autohide_behavior]='(wait_time: 1000, transition_time: 200, handle_size: 4, unhide_delay: 200)'
    [autohover_delay_ms]='Some(500)'
    [background]='ThemeDefault'
    [border_radius]='160'
    [exclusive_zone]='true'
    [expand_to_edges]='false'
    [keep_style_on_maximize]='true'
    [keyboard_interactivity]='OnDemand'
    [layer]='Top'
    [margin]='4'
    [name]='"Dock"'
    [opacity]='0.9'
    [output]="$dock_output"
    [padding]='4'
    [padding_overlap]='0.5'
    [plugins_center]='Some(["com.system76.CosmicAppList"])'
    [plugins_wings]='Some(([], []))'
    [size]='M'
    [size_center]='None'
    [size_wings]='None'
    [spacing]='0'
)

for key in "${!dock_values[@]}"; do
    write_value "$dock_dir/$key" "${dock_values[$key]}"
done

if [[ "$DRY_RUN" == "false" ]]; then
    printf '%s\n' "$BACKUP_ID" > "$PROJECT_STATE_HOME/active-backup"
    rm -f -- "$ICONS_BEFORE_FILE"
fi

restart_cosmic_panel
INSTALL_FINISHED=true
trap - EXIT
if [[ "$DRY_RUN" == "true" ]]; then
    log 'Dry run complete; no files were changed'
else
    log "COSMIC Lavender Glass $PROJECT_VERSION installed"
    log "Restore point: $BACKUP_ID"
fi
