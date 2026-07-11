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

if [ "$#" -ne 3 ]; then
    log_error "Usage: $0 <DOWNLOADED_FILE> <EXTRACT_DIR> <OUTPUT_RAW_IMG>"
    exit 1
fi

DOWNLOADED_FILE="$1"
EXTRACT_DIR="$2"
OUTPUT_RAW_IMG="$3"

log_info "Validating inputs..."
if [ ! -f "$DOWNLOADED_FILE" ]; then
    log_error "Downloaded file does not exist: $DOWNLOADED_FILE"
    exit 1
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# Clean previous output
rm -f "$OUTPUT_RAW_IMG"

log_info "Detecting archive format of $DOWNLOADED_FILE..."

# Detect by extension first, then fallback to 'file' utility
EXT="${DOWNLOADED_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

# If it ends with .xz but has .img before it, handle it
FILENAME=$(basename "$DOWNLOADED_FILE")

is_sparse() {
    local img="$1"
    if [ ! -f "$img" ]; then
        return 1
    fi
    # Read first 4 bytes in hex
    local magic
    magic=$(od -An -tx4 -N4 "$img" | tr -d ' ' | tr -d '\n' | tr '[:upper:]' '[:lower:]')
    if [ "$magic" = "3aff26ed" ] || [ "$magic" = "ed26ff3a" ]; then
        return 0
    else
        return 1
    fi
}

extract_archive() {
    local file="$1"
    local dest="$2"
    
    log_info "Extracting $file to $dest..."
    
    if [[ "$file" =~ \.xz$ ]]; then
        log_info "Format: XZ compression"
        # Check if it is a single file xz or tar.xz
        if [[ "$file" =~ \.tar\.xz$ || "$file" =~ \.txz$ ]]; then
            tar -xJf "$file" -C "$dest"
        else
            # Extract to dest directory
            local out_name
            out_name=$(basename "$file" .xz)
            # If it's a .img.xz, out_name will be .img
            xz -d -c "$file" > "$dest/$out_name"
        fi
    elif [[ "$file" =~ \.7z$ ]]; then
        log_info "Format: 7z archive"
        7z x "$file" -o"$dest" -y
    elif [[ "$file" =~ \.zip$ ]]; then
        log_info "Format: ZIP archive"
        unzip -q "$file" -d "$dest"
    elif [[ "$file" =~ \.tar\.gz$ || "$file" =~ \.tgz$ ]]; then
        log_info "Format: Tarball GZ archive"
        tar -xzf "$file" -C "$dest"
    elif [[ "$file" =~ \.img$ ]]; then
        log_info "Format: Direct Raw/Sparse Image"
        cp "$file" "$dest/system.img"
    else
        # Fallback to checking by content type
        local file_type
        file_type=$(file -b "$file")
        if echo "$file_type" | grep -q -i "XZ compressed"; then
            log_info "Content Type: XZ compressed file"
            xz -d -c "$file" > "$dest/system.img"
        elif echo "$file_type" | grep -q -i "7-zip archive"; then
            log_info "Content Type: 7-zip archive"
            7z x "$file" -o"$dest" -y
        elif echo "$file_type" | grep -q -i "Zip archive"; then
            log_info "Content Type: ZIP archive"
            unzip -q "$file" -d "$dest"
        elif echo "$file_type" | grep -q -i "Android sparse image"; then
            log_info "Content Type: Android sparse image"
            cp "$file" "$dest/system.img"
        else
            log_warn "Unknown file type. Copying directly as system.img..."
            cp "$file" "$dest/system.img"
        fi
    fi
}

extract_archive "$DOWNLOADED_FILE" "$EXTRACT_DIR"

log_info "Locating GSI system image in extracted files..."
# Find all files with .img extension and find the largest one
# Often GSIs are packed with metadata or small partition images (boot, vbmeta)
largest_img=""
max_size=0

while IFS= read -r -d '' img; do
    sz=$(stat -c%s "$img")
    if [ "$sz" -gt "$max_size" ]; then
        max_size="$sz"
        largest_img="$img"
    fi
done < <(find "$EXTRACT_DIR" -type f -name "*.img" -print0)

# If no .img files were found, check if there's any file that doesn't have an extension
# and could be the image
if [ -z "$largest_img" ]; then
    log_warn "No .img files found. Scanning for large files..."
    while IFS= read -r -d '' f; do
        sz=$(stat -c%s "$f")
        # Over 500MB is likely the system image
        if [ "$sz" -gt 524288000 ] && [ "$sz" -gt "$max_size" ]; then
            max_size="$sz"
            largest_img="$f"
        fi
    done < <(find "$EXTRACT_DIR" -type f -print0)
fi

if [ -z "$largest_img" ] || [ ! -f "$largest_img" ]; then
    log_error "Failed to locate any valid system image (.img) in extracted contents."
    exit 1
fi

log_success "Found GSI system image: $(basename "$largest_img") ($(du -sh "$largest_img" | cut -f1))"

# Check if the located image is sparse
log_info "Checking if GSI image is sparse format..."
if is_sparse "$largest_img"; then
    log_info "Detected: Sparse Android Image. Converting to RAW ext4/erofs image using simg2img..."
    if ! command -v simg2img &> /dev/null; then
        log_error "simg2img utility is missing! Please install it."
        exit 1
    fi
    simg2img "$largest_img" "$OUTPUT_RAW_IMG"
    log_success "Conversion to raw image completed."
else
    log_info "Detected: Raw Image (No conversion needed)."
    cp "$largest_img" "$OUTPUT_RAW_IMG"
fi

if [ ! -f "$OUTPUT_RAW_IMG" ] || [ ! -s "$OUTPUT_RAW_IMG" ]; then
    log_error "Failed to produce raw image file at $OUTPUT_RAW_IMG"
    exit 1
fi

log_success "Raw GSI system image is ready at $OUTPUT_RAW_IMG"
ls -lh "$OUTPUT_RAW_IMG"
file "$OUTPUT_RAW_IMG"
