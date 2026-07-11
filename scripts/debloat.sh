#!/usr/bin/env bash
set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [ "$#" -ne 1 ]; then
    log_error "Usage: $0 <SYSTEM_DIR>"
    exit 1
fi

SYS_ROOT="$1"

log_info "Validating system directory..."
if [ ! -d "$SYS_ROOT" ]; then
    log_error "Directory does not exist: $SYS_ROOT"
    exit 1
fi

# Detect root structure
# If there is a nested 'system' directory inside the root (System-as-root), use it
if [ -d "$SYS_ROOT/system" ] && [ -d "$SYS_ROOT/system/app" ]; then
    SYS_ROOT="$SYS_ROOT/system"
    log_info "System-as-root detected. Modifying inside subfolder: $SYS_ROOT"
fi

# 1. Remove Wallpapers
if [ "${REMOVE_WALLPAPERS:-false}" = "true" ]; then
    log_info "Removing static wallpapers..."
    # Wallpapers are usually stored in media/wallpaper, media/wallpapers or inside product/media
    dirs=(
        "$SYS_ROOT/media/wallpaper"
        "$SYS_ROOT/media/wallpapers"
        "$SYS_ROOT/etc/wallpaper"
        "$SYS_ROOT/system_ext/media/wallpaper"
        "$SYS_ROOT/product/media/wallpaper"
    )
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Removing wallpaper directory: $dir"
            sudo rm -rf "$dir"
        fi
    done
    log_success "Static wallpapers debloated."
fi

# 2. Remove Sounds
if [ "${REMOVE_SOUNDS:-false}" = "true" ]; then
    log_info "Removing system audio/sounds (alarms, ringtones, notifications, ui)..."
    dirs=(
        "$SYS_ROOT/media/audio"
        "$SYS_ROOT/system_ext/media/audio"
        "$SYS_ROOT/product/media/audio"
    )
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Removing audio directory: $dir"
            sudo rm -rf "$dir"
        fi
    done
    log_success "System sounds debloated."
fi

# 3. Remove Fonts
if [ "${REMOVE_FONTS:-false}" = "true" ]; then
    log_info "Removing non-essential fonts (preserving Roboto family to prevent bootloop)..."
    # To prevent bootloops, we MUST keep Roboto fonts and NotoColorEmoji (unless emojis aren't needed, but emojis are highly recommended to avoid crash UI).
    # We can delete extra CJK languages or NotoSans fonts that are huge (over 200MB in total).
    if [ -d "$SYS_ROOT/fonts" ]; then
        # Find all NotoSans and NotoSerif files in the fonts folder and delete them
        # Except NotoColorEmoji.ttf which is critical for emojis and UI rendering in some apps
        log_info "Deleting large NotoSans and NotoSerif font files..."
        sudo find "$SYS_ROOT/fonts" -type f \( -name "NotoSans*.ttf" -o -name "NotoSans*.ttc" -o -name "NotoSerif*.ttf" -o -name "NotoSerif*.ttc" \) ! -name "*NotoColorEmoji*" -exec sudo rm -f {} +
        log_success "Non-essential fonts removed."
    else
        log_warn "Fonts folder not found at $SYS_ROOT/fonts."
    fi
fi

# 4. Remove Live Wallpapers
if [ "${REMOVE_LIVE_WALLPAPERS:-false}" = "true" ]; then
    log_info "Removing Live Wallpapers picker and apps..."
    # Live wallpapers are apk files inside app/ and priv-app/ in various system partitions
    live_wp_patterns=(
        "*LiveWallpaper*"
        "*BasicLiveWallpaper*"
        "LiveWallpapersPicker"
    )
    
    search_paths=(
        "$SYS_ROOT/app"
        "$SYS_ROOT/priv-app"
        "$SYS_ROOT/system_ext/app"
        "$SYS_ROOT/system_ext/priv-app"
        "$SYS_ROOT/product/app"
        "$SYS_ROOT/product/priv-app"
    )

    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            for pattern in "${live_wp_patterns[@]}"; do
                sudo find "$path" -maxdepth 2 -type d -name "$pattern" -exec sudo rm -rf {} + 2>/dev/null || true
                sudo find "$path" -maxdepth 2 -type f -name "$pattern.apk" -exec sudo rm -f {} + 2>/dev/null || true
            done
        fi
    done
    log_success "Live wallpapers debloated."
fi

# 5. Remove Pixel Themes
if [ "${REMOVE_PIXEL_THEMES:-false}" = "true" ]; then
    log_info "Removing Pixel theme overlays and packages..."
    # Theme overlays are usually under overlays/
    theme_patterns=(
        "*PixelTheme*"
        "*PixelOverlay*"
        "*SystemUIPixel*"
        "PixelTheme*"
        "PixelOverlay*"
    )
    search_paths=(
        "$SYS_ROOT/overlay"
        "$SYS_ROOT/system_ext/overlay"
        "$SYS_ROOT/product/overlay"
        "$SYS_ROOT/vendor/overlay"
    )

    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            for pattern in "${theme_patterns[@]}"; do
                sudo find "$path" -maxdepth 2 -type d -name "$pattern" -exec sudo rm -rf {} + 2>/dev/null || true
                sudo find "$path" -maxdepth 2 -type f -name "$pattern.apk" -exec sudo rm -f {} + 2>/dev/null || true
            done
        fi
    done
    log_success "Pixel themes and overlays debloated."
fi

log_success "Debloat script finished."
