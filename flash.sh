#!/usr/bin/env bash
# Download the latest successful firmware build and flash it to each half.
#
#   ./flash.sh              download latest green build, then flash both halves
#   ./flash.sh --run <id>   flash a specific GitHub Actions run
#   ./flash.sh --dir <path> flash .uf2 files you already have
#   ./flash.sh --no-backup  skip reading CURRENT.UF2 off each half first
#
# Requires: gh (authenticated), udisksctl, lsblk.

set -euo pipefail

REPO="claytharrison/corne-zmk-config"
BACKUP_DIR="${HOME}/.local/share/corne-firmware-backups"
FW_DIR=""
RUN_ID=""
DO_BACKUP=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run)       RUN_ID="$2"; shift 2 ;;
        --dir)       FW_DIR="$2"; shift 2 ;;
        --no-backup) DO_BACKUP=0; shift ;;
        -h|--help)   sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)           echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

for cmd in udisksctl lsblk; do
    command -v "$cmd" >/dev/null || { echo "missing required command: $cmd" >&2; exit 1; }
done

# ---------------------------------------------------------------- get firmware

if [[ -z "$FW_DIR" ]]; then
    command -v gh >/dev/null || { echo "missing required command: gh" >&2; exit 1; }

    if [[ -z "$RUN_ID" ]]; then
        echo "==> Finding latest successful build..."
        RUN_ID=$(gh run list -R "$REPO" --status success --limit 1 \
                    --json databaseId -q '.[0].databaseId')
        [[ -n "$RUN_ID" ]] || { echo "no successful runs found" >&2; exit 1; }
    fi

    # Warn if the build predates local commits -- easy mistake to make.
    RUN_SHA=$(gh run list -R "$REPO" --limit 20 --json databaseId,headSha \
                -q ".[] | select(.databaseId==$RUN_ID) | .headSha")
    echo "==> Run $RUN_ID (commit ${RUN_SHA:0:7})"
    if [[ -n "$RUN_SHA" ]] && ! git -C "$(dirname "$0")" merge-base --is-ancestor \
            "$RUN_SHA" HEAD 2>/dev/null; then
        echo "    note: this build's commit is not an ancestor of your HEAD"
    fi
    if [[ "$RUN_SHA" != "$(git -C "$(dirname "$0")" rev-parse HEAD 2>/dev/null)" ]]; then
        echo "    warning: HEAD has commits newer than this build -- push first?"
    fi

    FW_DIR=$(mktemp -d)
    trap 'rm -rf "$FW_DIR"' EXIT
    gh run download "$RUN_ID" -R "$REPO" -D "$FW_DIR" >/dev/null
    # Artifacts unpack one level deep.
    [[ -d "$FW_DIR/firmware" ]] && FW_DIR="$FW_DIR/firmware"
fi

LEFT_UF2=$(find "$FW_DIR" -name '*left*.uf2' | head -1)
RIGHT_UF2=$(find "$FW_DIR" -name '*right*.uf2' | head -1)
[[ -f "$LEFT_UF2" && -f "$RIGHT_UF2" ]] || {
    echo "could not find left/right .uf2 in $FW_DIR" >&2; exit 1; }
echo "    left:  $(basename "$LEFT_UF2")"
echo "    right: $(basename "$RIGHT_UF2")"

# ------------------------------------------------------------------- flash one

# Returns the /dev node of a mounted-or-mountable Corne bootloader drive.
find_bootloader_dev() {
    lsblk -nr -o NAME,LABEL | awk '$2 ~ /^CORNE-MIN-[LR]$/ {print "/dev/"$1; exit}'
}

flash_half() {
    local dev="$1" label="$2" uf2 side
    case "$label" in
        CORNE-MIN-L) uf2="$LEFT_UF2";  side="LEFT"  ;;
        CORNE-MIN-R) uf2="$RIGHT_UF2"; side="RIGHT" ;;
        *) echo "unrecognized drive label: $label" >&2; return 1 ;;
    esac

    echo "==> $side half detected ($label)"
    local mnt
    mnt=$(lsblk -no MOUNTPOINT "$dev" | tr -d ' ')
    if [[ -z "$mnt" ]]; then
        udisksctl mount -b "$dev" >/dev/null
        mnt=$(lsblk -no MOUNTPOINT "$dev" | tr -d ' ')
    fi
    [[ -n "$mnt" ]] || { echo "could not mount $dev" >&2; return 1; }

    if [[ "$DO_BACKUP" -eq 1 && -f "$mnt/CURRENT.UF2" ]]; then
        mkdir -p "$BACKUP_DIR"
        local stamp backup
        stamp=$(date +%Y%m%d-%H%M%S)
        backup="$BACKUP_DIR/${label}-${stamp}.uf2"
        cp "$mnt/CURRENT.UF2" "$backup"
        echo "    backed up existing firmware -> $backup"
    fi

    echo "    writing $(basename "$uf2")..."
    cp "$uf2" "$mnt/"
    sync

    echo -n "    waiting for reboot"
    local waited=0
    while [[ -e "$dev" ]] && (( waited < 30 )); do
        sleep 1; waited=$((waited + 1)); echo -n "."
    done
    echo " done."
    echo "    $side half flashed."
}

# ----------------------------------------------------------------- main loop

echo
echo "Put a half into bootloader mode to flash it."
echo "  Bootloader key: hold both middle thumb keys (LOWER + layer 3),"
echo "  then press the outermost key on row 3 -- left end = left half,"
echo "  right end = right half."
echo "  No reset button on this board; fallback is shorting RST to GND twice."
echo
echo "Waiting for a bootloader drive (Ctrl-C to stop)..."

flashed=""
while true; do
    dev=$(find_bootloader_dev || true)
    if [[ -n "$dev" ]]; then
        label=$(lsblk -no LABEL "$dev" | tr -d ' ')
        flash_half "$dev" "$label" || true
        flashed="$flashed $label"
        if [[ "$flashed" == *"CORNE-MIN-L"* && "$flashed" == *"CORNE-MIN-R"* ]]; then
            echo
            echo "Both halves flashed. Test typing on each side."
            exit 0
        fi
        echo
        echo "Now put the other half into bootloader mode (Ctrl-C if done)..."
    fi
    sleep 2
done
