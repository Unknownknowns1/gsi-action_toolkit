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
    log_error "Usage: $0 <TARGET_FILE> <OUTPUT_CHECKSUM_FILE>"
    exit 1
fi

TARGET_FILE="$1"
OUTPUT_CHECKSUM_FILE="$2"

log_info "Validating inputs for checksum..."
if [ ! -f "$TARGET_FILE" ]; then
    log_error "Target file does not exist: $TARGET_FILE"
    exit 1
fi

# Ensure parent directory of output checksum file exists
mkdir -p "$(dirname "$OUTPUT_CHECKSUM_FILE")"
rm -f "$OUTPUT_CHECKSUM_FILE"

log_info "Generating SHA256 checksum for: $(basename "$TARGET_FILE")..."
# Generate checksum and output it
sha256_val=$(sha256sum "$TARGET_FILE" | cut -d' ' -f1)

log_info "SHA256: $sha256_val"

# Write standard sha256sum format (hash filename)
echo "$sha256_val  $(basename "$TARGET_FILE")" > "$OUTPUT_CHECKSUM_FILE"

log_success "Checksum file created at $OUTPUT_CHECKSUM_FILE"
cat "$OUTPUT_CHECKSUM_FILE"
