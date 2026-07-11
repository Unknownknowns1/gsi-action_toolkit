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
    log_error "Usage: $0 <IMAGE_PATH> <COMPRESSION_TYPE> <OUTPUT_PATH>"
    exit 1
fi

IMAGE_PATH="$1"
COMPRESSION_TYPE="$2"
OUTPUT_PATH="$3"

log_info "Validating inputs for compression..."
if [ ! -f "$IMAGE_PATH" ]; then
    log_error "Input image file does not exist: $IMAGE_PATH"
    exit 1
fi

# Convert compression type to lowercase
COMP_TYPE=$(echo "$COMPRESSION_TYPE" | tr '[:upper:]' '[:lower:]')

# Clean previous output
rm -f "$OUTPUT_PATH"
mkdir -p "$(dirname "$OUTPUT_PATH")"

log_info "Compression requested: $COMP_TYPE"

case "$COMP_TYPE" in
    none)
        log_info "No compression requested. Copying image directly to output..."
        cp "$IMAGE_PATH" "$OUTPUT_PATH"
        ;;
    xz)
        log_info "Compressing with XZ..."
        # -T0 uses all available CPU threads
        # -9 is the maximum compression ratio (can use -6 for better speed/memory, let's use -6 which is default but still high and uses much less RAM)
        # Using -6 for standard compatibility and fast decompression.
        xz -c -6 -T0 "$IMAGE_PATH" > "$OUTPUT_PATH"
        ;;
    7z)
        log_info "Compressing with 7zip..."
        # -mx=9 is ultra compression
        # -mmt=on uses multi-threading
        7z a -mx=5 -mmt=on "$OUTPUT_PATH" "$IMAGE_PATH"
        ;;
    *)
        log_error "Unsupported compression type: $COMP_TYPE (must be 'none', 'xz', or '7z')"
        exit 1
        ;;
esac

if [ ! -f "$OUTPUT_PATH" ] || [ ! -s "$OUTPUT_PATH" ]; then
    log_error "Failed to create compressed output file at $OUTPUT_PATH"
    exit 1
fi

log_success "Compression completed successfully!"
ls -lh "$OUTPUT_PATH"
