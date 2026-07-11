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

log_info "Validating inputs for build_ext4..."
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Ensure output path directory exists
mkdir -p "$(dirname "$OUTPUT_IMAGE")"
rm -f "$OUTPUT_IMAGE"

log_info "Calculating size of source directory..."
# Calculate directory size in KB
DIR_SIZE_KB=$(sudo du -s "$SOURCE_DIR" | cut -f1)
log_info "Source directory size: ${DIR_SIZE_KB} KB (~$((DIR_SIZE_KB / 1024)) MB)"

# We need extra space for ext4 metadata, inodes, block descriptors, and general safety.
# We will use 15% extra space + 150 MB safety margin.
EXTRA_MARGIN_KB=$(( (DIR_SIZE_KB * 15 / 100) + 153600 ))
TARGET_SIZE_KB=$(( DIR_SIZE_KB + EXTRA_MARGIN_KB ))

log_info "Creating raw image of size: ${TARGET_SIZE_KB} KB (~$((TARGET_SIZE_KB / 1024)) MB)..."
if ! dd if=/dev/zero of="$OUTPUT_IMAGE" bs=1024 count="$TARGET_SIZE_KB" status=progress; then
    log_error "Failed to create blank image file."
    exit 1
fi

log_info "Formatting image as ext4 filesystem..."
# -F forces formatting a file
# -b 4096 sets block size to 4096 (standard for Android partitions)
# -O ^metadata_csum avoids issues with older Android kernels that don't support modern metadata checksums
if ! mkfs.ext4 -F -b 4096 -O ^metadata_csum "$OUTPUT_IMAGE"; then
    log_error "Failed to format ext4 filesystem."
    rm -f "$OUTPUT_IMAGE"
    exit 1
fi

# Create a temporary mount point
MNT_DIR=$(mktemp -d -p "$PWD" mnt_ext4.XXXXXX)
log_info "Mounting loop device to $MNT_DIR..."

if ! sudo mount -o loop,rw "$OUTPUT_IMAGE" "$MNT_DIR"; then
    log_error "Failed to mount empty ext4 image."
    rm -rf "$MNT_DIR"
    rm -f "$OUTPUT_IMAGE"
    exit 1
fi

# Perform copying using cp -a to preserve permissions, xattrs (SELinux), ownership, links etc.
log_info "Copying files from workspace directory to mounted ext4 filesystem..."
if ! sudo cp -a "$SOURCE_DIR/." "$MNT_DIR/"; then
    log_error "Failed to copy files to target filesystem. Unmounting..."
    sudo umount "$MNT_DIR"
    rm -rf "$MNT_DIR"
    rm -f "$OUTPUT_IMAGE"
    exit 1
fi

log_info "Unmounting loop device..."
sudo umount "$MNT_DIR"
rm -rf "$MNT_DIR"

log_info "Running filesystem check and optimization (e2fsck)..."
# -f forces check, -y answers yes to all questions
sudo e2fsck -fy "$OUTPUT_IMAGE" || true

log_info "Shrinking ext4 filesystem to minimal size (resize2fs)..."
# -M minimizes the filesystem
if ! sudo resize2fs -M "$OUTPUT_IMAGE"; then
    log_warn "Failed to shrink the ext4 image. Leaving size as is."
fi

# Final check
sudo e2fsck -fy "$OUTPUT_IMAGE" || true

log_success "EXT4 GSI image built successfully!"
ls -lh "$OUTPUT_IMAGE"
file "$OUTPUT_IMAGE"
