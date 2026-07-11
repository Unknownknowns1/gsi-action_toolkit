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

if [ "$#" -ne 2 ]; then
    log_error "Usage: $0 <SOURCE_DIR> <OUTPUT_IMAGE>"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_IMAGE="$2"

log_info "Validating inputs for build_erofs..."
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Ensure output path directory exists
mkdir -p "$(dirname "$OUTPUT_IMAGE")"
rm -f "$OUTPUT_IMAGE"

log_info "Searching for plat_file_contexts to preserve Android SELinux contexts..."
FC_FILE=$(find "$SOURCE_DIR" -name plat_file_contexts | head -n 1)

# Generate a random UUID
FS_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "12345678-1234-1234-1234-123456789abc")

# Set up base options
# -b 4096: Sets filesystem block size to 4096 (standard for Android)
# -U: Sets UUID
# -E ztailpacking: Inlines tail parts of files into metadata to save space
# -z lz4hc: High compression mode, highly compatible with modern Android kernels
MKER_OPTS=("-b" "4096" "-U" "$FS_UUID" "-E" "ztailpacking" "-z" "lz4hc")

if [ -n "$FC_FILE" ] && [ -f "$FC_FILE" ]; then
    log_success "Found plat_file_contexts at: $FC_FILE"
    MKER_OPTS+=("--file-contexts=$FC_FILE")
else
    log_warn "plat_file_contexts not found! The rebuilt EROFS image may have incorrect SELinux contexts."
fi

log_info "Building EROFS GSI system image..."
# Run mkfs.erofs using sudo to ensure we read source files with all attributes
if ! sudo mkfs.erofs "${MKER_OPTS[@]}" "$OUTPUT_IMAGE" "$SOURCE_DIR"; then
    log_error "Failed to build EROFS image using mkfs.erofs."
    rm -f "$OUTPUT_IMAGE"
    exit 1
fi

log_success "EROFS GSI image built successfully!"
ls -lh "$OUTPUT_IMAGE"
file "$OUTPUT_IMAGE"
