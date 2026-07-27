#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN=false
LIST_BACKUPS=false
BACKUP_ID=""

usage() {
    printf '%s\n' \
        "Usage: ./uninstall.sh [--list-backups] [--backup ID] [--dry-run]" \
        '' \
        '  --list-backups  List available restore points and exit.' \
        '  --backup ID     Restore a specific backup (latest by default).' \
        '  --dry-run       Print the planned restoration without writing.'
}

while (($#)); do
    case "$1" in
        --list-backups)
            LIST_BACKUPS=true
            shift
            ;;
        --backup)
            (($# >= 2)) || die '--backup requires an ID'
            BACKUP_ID="$2"
            shift 2
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

require_home

if [[ "$LIST_BACKUPS" == "true" ]]; then
    if [[ ! -d "$BACKUPS_HOME" ]]; then
        printf 'No backups found.\n'
        exit 0
    fi
    active=""
    [[ -f "$PROJECT_STATE_HOME/active-backup" ]] &&
        active="$(<"$PROJECT_STATE_HOME/active-backup")"
    while IFS= read -r item; do
        if [[ "$item" == "$active" ]]; then
            printf '%s (active)\n' "$item"
        else
            printf '%s\n' "$item"
        fi
    done < <(find "$BACKUPS_HOME" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort -r)
    exit 0
fi

if [[ -z "$BACKUP_ID" ]]; then
    if [[ -f "$PROJECT_STATE_HOME/active-backup" ]]; then
        BACKUP_ID="$(<"$PROJECT_STATE_HOME/active-backup")"
    else
        BACKUP_ID="$(latest_backup)" || die 'no backups found'
    fi
fi
validate_backup_id "$BACKUP_ID"
BACKUP_DIR="$BACKUPS_HOME/$BACKUP_ID"

log "Restoring backup $BACKUP_ID"
restore_backup_files "$BACKUP_DIR"
remove_installed_icons "$BACKUP_DIR"
restore_project_wallpaper "$BACKUP_DIR"

if [[ "$DRY_RUN" == "false" && -f "$PROJECT_STATE_HOME/active-backup" ]] &&
    [[ "$(<"$PROJECT_STATE_HOME/active-backup")" == "$BACKUP_ID" ]]; then
    rm -f -- "$PROJECT_STATE_HOME/active-backup"
fi

restart_cosmic_panel
log 'Previous COSMIC configuration restored'
