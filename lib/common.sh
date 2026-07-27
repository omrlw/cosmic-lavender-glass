#!/usr/bin/env bash

PROJECT_ID="cosmic-lavender-glass"
PROJECT_VERSION="1.0.0"
MAC_TAHOE_REPO="https://github.com/vinceliuice/MacTahoe-icon-theme.git"
MAC_TAHOE_COMMIT="77eebfcdb5bf7074a2877eaee63f1bf48a994d5e"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '==> %s\n' "$*"
}

run() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

require_home() {
    [[ -n "${HOME:-}" && "$HOME" == /* ]] || die 'HOME must be an absolute path'
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    COSMIC_CONFIG_HOME="$XDG_CONFIG_HOME/cosmic"
    PROJECT_STATE_HOME="$XDG_STATE_HOME/$PROJECT_ID"
    BACKUPS_HOME="$PROJECT_STATE_HOME/backups"
    ICONS_HOME="$XDG_DATA_HOME/icons"
    WALLPAPER_HOME="$XDG_DATA_HOME/backgrounds/$PROJECT_ID"
}

validate_backup_id() {
    [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z(-[0-9]+)?$ ]] ||
        die "invalid backup ID: $1"
}

latest_backup() {
    [[ -d "$BACKUPS_HOME" ]] || return 1
    find "$BACKUPS_HOME" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
        LC_ALL=C sort | tail -n 1
}

backup_targets() {
    printf '%s\n' \
        'com.system76.CosmicTheme.Light.Builder' \
        'com.system76.CosmicTheme.Light' \
        'com.system76.CosmicTheme.Mode' \
        'com.system76.CosmicTk/v1/icon_theme' \
        'com.system76.CosmicPanel.Dock/v1' \
        'com.system76.CosmicBackground/v1/all'
}

create_backup() {
    local backup_id candidate target
    backup_id="$(date -u +%Y%m%dT%H%M%SZ)"
    candidate="$BACKUPS_HOME/$backup_id"
    if [[ -e "$candidate" ]]; then
        backup_id="${backup_id}-$$"
        candidate="$BACKUPS_HOME/$backup_id"
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log "Would create backup $backup_id"
        BACKUP_ID="$backup_id"
        BACKUP_DIR="$candidate"
        return
    fi

    mkdir -p "$candidate/config"
    : > "$candidate/present"
    : > "$candidate/missing"
    while IFS= read -r target; do
        if [[ -e "$COSMIC_CONFIG_HOME/$target" ]]; then
            printf '%s\n' "$target" >> "$candidate/present"
            mkdir -p "$candidate/config/$(dirname "$target")"
            cp -a "$COSMIC_CONFIG_HOME/$target" "$candidate/config/$target"
        else
            printf '%s\n' "$target" >> "$candidate/missing"
        fi
    done < <(backup_targets)

    if [[ -f "$ICONS_HOME/MacTahoe/index.theme" ]]; then
        printf 'true\n' > "$candidate/mactahoe-preexisting"
    else
        printf 'false\n' > "$candidate/mactahoe-preexisting"
    fi
    if [[ -d "$WALLPAPER_HOME" ]]; then
        printf 'true\n' > "$candidate/wallpaper-preexisting"
        cp -a "$WALLPAPER_HOME" "$candidate/wallpaper"
    else
        printf 'false\n' > "$candidate/wallpaper-preexisting"
    fi
    printf '%s\n' "$PROJECT_VERSION" > "$candidate/project-version"
    BACKUP_ID="$backup_id"
    BACKUP_DIR="$candidate"
    log "Backup saved as $backup_id"
}

restore_project_wallpaper() {
    local backup_dir="$1"
    run rm -rf -- "$WALLPAPER_HOME"
    if [[ -f "$backup_dir/wallpaper-preexisting" ]] &&
        [[ "$(<"$backup_dir/wallpaper-preexisting")" == "true" ]]; then
        [[ -d "$backup_dir/wallpaper" ]] || die 'wallpaper backup payload is missing'
        run mkdir -p "$(dirname "$WALLPAPER_HOME")"
        run cp -a "$backup_dir/wallpaper" "$WALLPAPER_HOME"
    fi
}

restore_backup_files() {
    local backup_dir="$1" target source
    [[ -d "$backup_dir" ]] || die "backup not found: $(basename "$backup_dir")"
    [[ -f "$backup_dir/present" && -f "$backup_dir/missing" ]] ||
        die "backup is incomplete: $(basename "$backup_dir")"

    while IFS= read -r target; do
        [[ -n "$target" ]] || continue
        source="$backup_dir/config/$target"
        [[ -e "$source" ]] || die "backup payload missing: $target"
        run mkdir -p "$(dirname "$COSMIC_CONFIG_HOME/$target")"
        run rm -rf -- "$COSMIC_CONFIG_HOME/$target"
        run cp -a "$source" "$COSMIC_CONFIG_HOME/$target"
    done < "$backup_dir/present"

    while IFS= read -r target; do
        [[ -n "$target" ]] || continue
        run rm -rf -- "$COSMIC_CONFIG_HOME/$target"
    done < "$backup_dir/missing"
}

remove_installed_icons() {
    local backup_dir="$1" icon_path
    [[ -f "$backup_dir/installed-icons" ]] || return 0
    while IFS= read -r icon_path; do
        [[ -n "$icon_path" ]] || continue
        case "$icon_path" in
            "$ICONS_HOME"/MacTahoe*) run rm -rf -- "$icon_path" ;;
            *) die "refusing to remove unexpected icon path: $icon_path" ;;
        esac
    done < "$backup_dir/installed-icons"
}

restart_cosmic_panel() {
    case ":${XDG_CURRENT_DESKTOP:-}:" in
        *:COSMIC:*|*:cosmic:*)
            if command -v pgrep >/dev/null 2>&1 && pgrep -x cosmic-panel >/dev/null 2>&1; then
                log 'Restarting cosmic-panel'
                run pkill -TERM -x cosmic-panel
            fi
            ;;
    esac
}
