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
    log_error "Usage: $0 <GSI_URL> <OUTPUT_PATH>"
    exit 1
fi

GSI_URL="$1"
OUTPUT_PATH="$2"

log_info "Validating inputs..."
if [ -z "$GSI_URL" ]; then
    log_error "GSI URL cannot be empty."
    exit 1
fi

# Basic URL check
if [[ ! "$GSI_URL" =~ ^https?:// ]]; then
    log_error "Invalid URL format: $GSI_URL (must start with http:// or https://)"
    exit 1
fi

# Ensure output directory exists
OUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUT_DIR"

log_info "Downloading GSI from: $GSI_URL"
log_info "Output destination: $OUTPUT_PATH"

# Choose downloader
if command -v axel &> /dev/null; then
    log_info "Using Axel (multi-threaded download)..."
    if ! axel -n 8 -q -o "$OUTPUT_PATH" "$GSI_URL"; then
        log_warn "Axel download failed. Falling back to curl..."
        rm -f "$OUTPUT_PATH" # Clean partial download
        curl -sS -L -o "$OUTPUT_PATH" "$GSI_URL"
    fi
elif command -v curl &> /dev/null; then
    log_info "Using Curl..."
    curl -sS -L -o "$OUTPUT_PATH" "$GSI_URL"
elif command -v wget &> /dev/null; then
    log_info "Using Wget..."
    wget -q -O "$OUTPUT_PATH" "$GSI_URL"
else
    log_error "No supported downloader found (axel, curl, or wget is required)."
    exit 1
fi

if [ ! -f "$OUTPUT_PATH" ] || [ ! -s "$OUTPUT_PATH" ]; then
    log_error "Download failed: File is empty or does not exist."
    exit 1
fi

log_success "Download completed successfully!"
ls -lh "$OUTPUT_PATH"
