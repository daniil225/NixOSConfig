#!/usr/bin/env bash
# ==============================================================================
# disk_setup.sh — Interactive disk configuration wizard for NixOS installation
# ------------------------------------------------------------------------------
# Purpose:
#   Collects disk-related preferences from the user for NixOS installation:
#     - Installation mode (clear disk or dual-boot alongside existing OS)
#     - Target disk selection
#     - Partition sizes (boot, swap)
#     - Filesystem type (ext4 or btrfs)
#     - Root partition (for neighbor/dual-boot mode)
#
# Workflow:
#   1. Prompts for installation mode (clear vs neighbor)
#   2. Scans available disks and lets user select target disk
#   3. Collects mode-specific configuration:
#      - Clear mode: boot size, swap size, filesystem type
#      - Neighbor mode: root partition, swap size, filesystem type
#   4. Displays final summary of collected disk preferences
#
# Dependencies:
#   - utils.sh  (logging helpers: log_info, log_warning, log_error)
#   - guard_run (idempotency guard)
#   - lsblk     (disk scanning and partition listing)
#
# Globals written:
#   - SETUP_DISK_PREFERENCES (associative array with all disk settings)
#
# Note:
#   This script is designed to be sourced by the main installer (install.sh).
#   The final `disk_setup` call at the end is for standalone testing only.
# ==============================================================================

# ------------------------------------------------------------------------------
# Bootstrap: load shared utilities and activate the run guard.
# ------------------------------------------------------------------------------
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/utils.sh"
guard_run "${BASH_SOURCE[0]}" "${0}"


# ==============================================================================
# Disk setup preferences
# ==============================================================================
# All disk-related settings are collected here, separately from the global
# SETUP_PREFERENCES, to keep concerns isolated and make the disko-config
# generator easier to reason about.
# ==============================================================================
declare -A SETUP_DISK_PREFERENCES=(
    [target_disk]=""          # e.g. nvme0n1 (without /dev/ prefix)
    [disk_by_id]=""           # disk name in this way: /dev/
    [install_mode]=""         # "clear" or "neighbor"
    [boot_size]="1G"          # Only used in clear install
    [swap_size]="4G"          # 0 means disabled
    [root_size]="100%"        # By default, all remaining free space
    [root_fs_type]="ext4"     # "ext4" or "btrfs"
    [boot_fs_type]="vfat"     # Boot filesystem type
    [swap_fs_type]="swap"     # Swap filesystem type
    [root_partition]=""       # Only used in neighbor install (e.g. nvme0n1p3)
    [boot_partition]=""       # Boot partition path
    [swap_partition]=""       # Swap partition path
)

# Internal variables for disk configuration generation
_SETUP_DISK_BOOT_CONF=""
_SETUP_DISK_SWAP_CONF=""
_SETUP_DISK_ROOT_CONF=""

# Generated disk config. Includes part from disk.main = { partitions ... }
SETUP_DISK_CONF=""

# Installation mode constants
# Using constants prevents typos and makes the code more maintainable.
readonly DISK_MODE_CLEAR="clear"
readonly DISK_MODE_NEIGHBOR="neighbor"
readonly DISKO_BOOT_LABEL="ESP"
readonly DISKO_ROOT_LABEL="root"
readonly DISKO_SWAP_LABEL="swap"
readonly DISK_BOOT_PARTLABEL="disk-main-${DISKO_BOOT_LABEL}"
readonly DISK_ROOT_PARTLABEL="disk-main-${DISKO_ROOT_LABEL}"
readonly DISK_SWAP_PARTLABEL="disk-main-${DISKO_SWAP_LABEL}"


# ==============================================================================
# Step 1: Installation Mode Selection
# ==============================================================================

# ------------------------------------------------------------------------------
# install_mode_selection()
#
# Description:
#   Prompts the user to choose between two installation modes:
#     1) Clear Install: wipes the entire disk and installs NixOS
#     2) Neighbor Install: installs NixOS alongside an existing OS (dual-boot)
#
# Side effects:
#   Sets SETUP_DISK_PREFERENCES[install_mode] to either DISK_MODE_CLEAR
#   or DISK_MODE_NEIGHBOR.
#
# Returns:
#   0 on success (always returns 0, as it loops until valid input)
# ------------------------------------------------------------------------------
install_mode_selection() {
    log_info "Select installation type:"
    log_info "  1) Full disk wipe (Clear Install) - NixOS takes the entire disk"
    log_info "  2) Install alongside existing OS  - Dual-boot with another OS"

    while true; do
        read -r -p "Installation type [1/2]: " choice
        case "$choice" in
            1)
                SETUP_DISK_PREFERENCES[install_mode]="$DISK_MODE_CLEAR"
                log_info "Selected: Clear Install"
                return 0
                ;;
            2)
                SETUP_DISK_PREFERENCES[install_mode]="$DISK_MODE_NEIGHBOR"
                log_info "Selected: Dual-boot (Neighbor Install)"
                return 0
                ;;
            *)
                log_warning "Please enter 1 or 2."
                ;;
        esac
    done
}


# ==============================================================================
# Step 2: Target Disk Selection
# ==============================================================================

# ------------------------------------------------------------------------------
# disk_selection()
#
# Description:
#   Scans available disks using lsblk and presents them to the user for selection.
#
# Implementation:
#   1. Uses `lsblk -d -n -o NAME,TYPE` to list all block devices
#   2. Filters for type "disk" (excludes partitions, loop devices, etc.)
#   3. For each disk, retrieves size and model using additional lsblk calls
#   4. Presents a numbered list and prompts for selection
#
# Side effects:
#   Sets SETUP_DISK_PREFERENCES[target_disk] to the selected disk name
#   (without /dev/ prefix).
#
# Returns:
#   0 on success
#   1 if no disks are found or selection fails
# ------------------------------------------------------------------------------
disk_selection() {
    log_info "Scanning available disks..."
    local disks=()
    
    # Parse lsblk output to extract disk names
    # Format: NAME TYPE (e.g., "nvme0n1 disk", "sda disk")
    while IFS= read -r line; do
        local name type
        name=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        if [[ "$type" == "disk" ]]; then
            disks+=("$name")
        fi
    done < <(lsblk -d -n -o NAME,TYPE 2>/dev/null)

    # Guard against empty disk list (e.g., in VM without disks)
    if [[ ${#disks[@]} -eq 0 ]]; then
        log_error "No valid disks found"
        return 1
    fi

    # Display available disks with size and model information
    log_info "Available disks:"
    for i in "${!disks[@]}"; do
        local disk="${disks[$i]}"
        local size model
        # Retrieve size and model for each disk
        size=$(lsblk -d -n -o SIZE "/dev/$disk" 2>/dev/null | xargs)
        model=$(lsblk -d -n -o MODEL "/dev/$disk" 2>/dev/null | xargs)
        log_info "  $((i + 1))) /dev/$disk - $size ${model:-}"
    done

    # Prompt for disk selection with validation
    while true; do
        read -r -p "Select target disk number [1-${#disks[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#disks[@]} )); then
            SETUP_DISK_PREFERENCES[target_disk]="${disks[$((choice - 1))]}"
            SETUP_DISK_PREFERENCES[disk_by_id]=$(lsblk  /dev/${SETUP_DISK_PREFERENCES[target_disk]} --output ID-LINK --noheading --nodeps)
            log_info "Selected disk: /dev/${SETUP_DISK_PREFERENCES[target_disk]}"
            return 0
        else
            log_warning "Invalid choice. Enter a number between 1 and ${#disks[@]}."
        fi
    done
}


# ==============================================================================
# Step 3a: Clear Install Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# configure_clear_install()
#
# Description:
#   Collects configuration for a full-disk wipe installation.
#
# Prompts for:
#   - Boot partition size (default: 1G, format: <number><M|G>)
#   - Swap partition size (default: 4G, 0 to disable)
#   - Filesystem type (ext4 or btrfs, default: btrfs)
#
# Side effects:
#   Updates SETUP_DISK_PREFERENCES with the collected values.
#
# Note:
#   Actual partitioning will be handled by Disko later. This function only
#   gathers user preferences.
# ------------------------------------------------------------------------------
configure_clear_install() {
    log_info "========================================="
    log_info "      Clear Install Configuration        "
    log_info "========================================="
    log_info "Note: Actual partitioning will be handled by Disko later."
    log_info "We just need to gather your preferences."
    log_info ""

    # Boot partition size
    local default_boot="${SETUP_DISK_PREFERENCES[boot_size]}"
    local input
    read -r -p "Boot partition size [$default_boot]: " input
    if [[ -n "$input" ]]; then
        # Validate format: number followed by M or G (case-insensitive)
        if [[ "$input" =~ ^[0-9]+[MmGg]$ ]]; then
            # Convert to uppercase for consistency (e.g., "1g" -> "1G")
            SETUP_DISK_PREFERENCES[boot_size]="${input^^}"
        else
            log_warning "Invalid format, using default: $default_boot"
        fi
    fi
    log_info "Boot size: ${SETUP_DISK_PREFERENCES[boot_size]}"

    # Swap partition size
    local default_swap="${SETUP_DISK_PREFERENCES[swap_size]}"
    read -r -p "Swap size [$default_swap] (use 0 to disable): " input
    if [[ -n "$input" ]]; then
        # Allow "0" (disabled) or valid size format
        if [[ "$input" == "0" ]] || [[ "$input" =~ ^[0-9]+[MmGg]$ ]]; then
            SETUP_DISK_PREFERENCES[swap_size]="${input^^}"
        else
            log_warning "Invalid format, using default: $default_swap"
        fi
    fi
    log_info "Swap size: ${SETUP_DISK_PREFERENCES[swap_size]}"

    # Filesystem type selection
    log_info ""
    log_info "Filesystem type:"
    log_info "  1) ext4  - Stable, widely compatible"
    log_info "  2) btrfs - Modern, snapshots, compression"
    local fs_choice
    read -r -p "Choice [1/2, default=1]: " fs_choice
    case "${fs_choice:-1}" in
        1) SETUP_DISK_PREFERENCES[root_fs_type]="ext4" ;;
        *) SETUP_DISK_PREFERENCES[root_fs_type]="btrfs" ;;
    esac
    log_info "Filesystem: ${SETUP_DISK_PREFERENCES[root_fs_type]}"

    log_info "========================================="
}


# ==============================================================================
# Helper Functions for Partition Management
# ==============================================================================

# ------------------------------------------------------------------------------
# get_base_disk()
#
# Description:
#   Extracts the base disk from a partition name.
#   Examples:
#     /dev/sda2       -> /dev/sda
#     /dev/nvme0n1p3  -> /dev/nvme0n1
#     /dev/mmcblk0p1  -> /dev/mmcblk0
# ------------------------------------------------------------------------------
get_base_disk() {
    local part="${1#/dev/}"
    if [[ "$part" =~ ^(nvme[0-9]+n[0-9]+|mmcblk[0-9]+)(p?[0-9]+)$ ]]; then
        echo "/dev/${BASH_REMATCH[1]}"
    elif [[ "$part" =~ ^([a-z]+[a-z0-9]*)([0-9]+)$ ]]; then
        echo "/dev/${BASH_REMATCH[1]}"
    fi
}

# ------------------------------------------------------------------------------
# get_part_num()
#
# Description:
#   Extracts the partition number from a partition path.
#   Examples:
#     /dev/sda2       -> 2
#     /dev/nvme0n1p3  -> 3
# ------------------------------------------------------------------------------
get_part_num() {
    local part="${1#/dev/}"
    if [[ "$part" =~ p([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$part" =~ [a-z]([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# ------------------------------------------------------------------------------
# set_partlabel()
#
# Description:
#   Helper function: sets the PARTLABEL for a specified partition.
#
# Arguments:
#   $1 - Partition path (e.g., /dev/sda1)
#   $2 - Label to set
# ------------------------------------------------------------------------------
set_partlabel() {
    local part_path="$1"
    local label="$2"
    local base partno
    
    base=$(get_base_disk "${part_path}")
    partno=$(get_part_num "${part_path}")
    
    if [[ -z "$base" || -z "$partno" ]]; then
        log_warning "Cannot determine parent disk/partition number for $part_path"
        return 1
    fi
    
    log_info "Setting PARTLABEL='$label' on $part_path ($base #$partno)"
    sudo sgdisk -c "${partno}":"${label}" "${base}"
}


# ==============================================================================
# Step 3b: Neighbor Install Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# configure_neighbor_install()
#
# Description:
#   Collects configuration for a dual-boot installation alongside an existing OS.
#
# Prompts for:
#   - Boot partition path
#   - Root partition path
#   - Swap partition path (optional)
#
# Side effects:
#   Updates SETUP_DISK_PREFERENCES with the collected values.
#   Applies PARTLABELs to the selected partitions.
#
# Implementation:
#   1. Displays current partitions on the target disk using lsblk
#   2. Prompts for the partitions to use
#   3. Collects sizes and filesystem types using lsblk
#   4. Applies PARTLABELs and updates the kernel partition table
# ------------------------------------------------------------------------------
configure_neighbor_install() {
    log_info "========================================="
    log_info "    Neighbor Install Configuration       "
    log_info "========================================="

    local disk="${SETUP_DISK_PREFERENCES[target_disk]}"

    # Display current partition layout to help user choose
    log_info "Current partitions on /dev/$disk:"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT "/dev/$disk" 2>/dev/null | while IFS= read -r line; do
        log_info "  $line"
    done
    log_info ""

    # 2a) Partition for boot
    while true; do
        read -r -p "Enter partition path for boot (e.g., /dev/${disk}1): " boot_part
        if [[ -b "$boot_part" ]]; then
            break
        fi
        log_warning "Not a valid block device: $boot_part"
    done

    # 2b) Partition for root
    while true; do
        read -r -p "Enter partition path for root (e.g., /dev/${disk}2): " root_part
        if [[ -b "$root_part" ]]; then
            break
        fi
        log_warning "Not a valid block device: $root_part"
    done

    # 2c) Partition for swap (optional, can be skipped)
    while true; do
        read -r -p "Enter partition path for swap (or press Enter to skip): " swap_part
        if [[ -z "$swap_part" ]]; then
            break
        fi
        if [[ -b "$swap_part" ]]; then
            break
        fi
        log_warning "Not a valid block device: $swap_part"
    done

    # Save the selection
    SETUP_DISK_PREFERENCES[boot_partition]="${boot_part}"
    SETUP_DISK_PREFERENCES[boot_size]=$(lsblk -o SIZE "${boot_part}" --noheading)
    SETUP_DISK_PREFERENCES[boot_fs_type]=$(lsblk -o FSTYPE "${boot_part}" --noheading)
    
    SETUP_DISK_PREFERENCES[root_partition]="$root_part"
    SETUP_DISK_PREFERENCES[root_size]=$(lsblk -o SIZE "${root_part}" --noheading)
    SETUP_DISK_PREFERENCES[root_fs_type]=$(lsblk -o FSTYPE "${root_part}" --noheading)
    
    if [[ -n "$swap_part" ]]; then
        SETUP_DISK_PREFERENCES[swap_partition]="${swap_part}"
        SETUP_DISK_PREFERENCES[swap_size]=$(lsblk -o SIZE "${swap_part}" --noheading)
    fi
    
    # 3) Apply PARTLABELs and finish
    log_info ""
    log_info "Applying PARTLABELs..."
    set_partlabel "$boot_part" "${DISK_BOOT_PARTLABEL}"
    set_partlabel "$root_part" "${DISK_ROOT_PARTLABEL}"
    if [[ -n "$swap_part" ]]; then
        set_partlabel "$swap_part" "${DISK_SWAP_PARTLABEL}"
    fi

    # Update the partition table in the kernel
    partprobe "/dev/$disk" 2>/dev/null || sleep 1

    log_info ""
    log_info "Final layout:"
    lsblk -o NAME,PARTLABEL,FSTYPE,SIZE "/dev/$disk" 2>/dev/null | while IFS= read -r line; do
        log_info "  $line"
    done
   
    log_info "========================================="
}


# ==============================================================================
# Summary and Configuration Generation
# ==============================================================================

# ------------------------------------------------------------------------------
# show_disk_setuped_preferences()
#
# Description:
#   Displays a summary of the collected disk configuration preferences.
# ------------------------------------------------------------------------------
show_disk_setuped_preferences() {
    log_info "Disk configuration collected:"
    log_info "  Install mode : ${SETUP_DISK_PREFERENCES[install_mode]}"
    log_info "  Target disk  : /dev/${SETUP_DISK_PREFERENCES[target_disk]}"
    log_info "  Target disk (by-id) : /dev/disk/by-id/${SETUP_DISK_PREFERENCES[disk_by_id]}"

    local mode="${SETUP_DISK_PREFERENCES[install_mode]}"

    if [[ "$mode" == "$DISK_MODE_NEIGHBOR" ]]; then
        local boot_part="${SETUP_DISK_PREFERENCES[boot_partition]}"
        local boot_size="${SETUP_DISK_PREFERENCES[boot_size]}"
        local boot_fs_type="${SETUP_DISK_PREFERENCES[boot_fs_type]}"
        
        local root_part="${SETUP_DISK_PREFERENCES[root_partition]}"
        local root_size="${SETUP_DISK_PREFERENCES[root_size]}"
        local root_fs_type="${SETUP_DISK_PREFERENCES[root_fs_type]}"

        local swap_part="${SETUP_DISK_PREFERENCES[swap_partition]}"
        local swap_size="${SETUP_DISK_PREFERENCES[swap_size]}"
        local swap_fs_type="${SETUP_DISK_PREFERENCES[swap_fs_type]}"

        log_info "  boot: $boot_part ${boot_fs_type:-unknown} ${boot_size:-?}"
        if [[ -n "$swap_part" ]]; then
            log_info "  swap: $swap_part ${swap_fs_type:-swap} ${swap_size:-?}"
        else
            log_info "  swap: (disabled)"
        fi
        log_info "  root: $root_part ${root_fs_type:-unknown} ${root_size:-?}"
        
    else
        # clear mode — without device paths
        log_info "  boot: vfat ${SETUP_DISK_PREFERENCES[boot_size]}"
        log_info "  swap: ${SETUP_DISK_PREFERENCES[swap_fs_type]} ${SETUP_DISK_PREFERENCES[swap_size]}"
        log_info "  root: ${SETUP_DISK_PREFERENCES[root_fs_type]} ${SETUP_DISK_PREFERENCES[root_size]}"
    fi
}

# ------------------------------------------------------------------------------
# init_setup_disk_boot_conf()
#
# Description:
#   Initializes _SETUP_DISK_BOOT_CONF using the initialized context for boot.
# ------------------------------------------------------------------------------
init_setup_disk_boot_conf() {
    _SETUP_DISK_BOOT_CONF=$(cat <<EOF 
    ${DISKO_BOOT_LABEL} = {
        type = "EF00";
        size = "${SETUP_DISK_PREFERENCES[boot_size]}";
        content = {
            type = "filesystem";
            format = "${SETUP_DISK_PREFERENCES[boot_fs_type]}";
            mountpoint = "/boot";
        };
    };
EOF
)
}

# ------------------------------------------------------------------------------
# init_setup_disk_swap_conf()
#
# Description:
#   Initializes _SETUP_DISK_SWAP_CONF using the initialized context for swap.
# ------------------------------------------------------------------------------
init_setup_disk_swap_conf() {
    _SETUP_DISK_SWAP_CONF=$(cat <<EOF
        ${DISKO_SWAP_LABEL} = {
            size = "${SETUP_DISK_PREFERENCES[swap_size]}";
            content = {
                type = "swap";
            };
        };
EOF
)
}

# ------------------------------------------------------------------------------
# init_setup_disk_root_conf()
#
# Description:
#   Initializes _SETUP_DISK_ROOT_CONF using the initialized context for root.
# ------------------------------------------------------------------------------
init_setup_disk_root_conf() {
    _SETUP_DISK_ROOT_CONF=$(cat <<EOF
    ${DISKO_ROOT_LABEL} = {
        size = "${SETUP_DISK_PREFERENCES[root_size]}";
        content = {
            type = "filesystem";
            format = "${SETUP_DISK_PREFERENCES[root_fs_type]}";
            mountpoint = "/";
        };
    };    
EOF
)
}

# ------------------------------------------------------------------------------
# init_setup_disk_conf()
#
# Description:
#   Assembles the disk configuration and initializes the global variable
#   SETUP_DISK_CONF, which is used to generate the disko.nix file.
# ------------------------------------------------------------------------------
init_setup_disk_conf() {
    init_setup_disk_boot_conf
    init_setup_disk_swap_conf
    init_setup_disk_root_conf

    SETUP_DISK_CONF="${_SETUP_DISK_BOOT_CONF}
    ${_SETUP_DISK_ROOT_CONF}
    ${_SETUP_DISK_SWAP_CONF}"    
}


# ==============================================================================
# Main Disk Setup Function
# ==============================================================================

# ------------------------------------------------------------------------------
# disk_setup()
#
# Description:
#   Top-level orchestrator for the disk configuration wizard.
#
# Workflow:
#   1. Prompts for installation mode (clear vs neighbor)
#   2. Scans and selects target disk
#   3. Collects mode-specific configuration:
#      - Clear mode: boot size, swap size, filesystem
#      - Neighbor mode: root partition, swap size, filesystem
#   4. Displays final summary of all collected preferences
#
# Side effects:
#   Populates SETUP_DISK_PREFERENCES with all disk-related settings.
#
# Returns:
#   0 on success
#   1 if any step fails (e.g., no disks found, unknown mode)
# ------------------------------------------------------------------------------
disk_setup() {
    log_info "========================================="
    log_info "              Disk Setup                 "
    log_info "========================================="

    # Step 1: Installation mode
    install_mode_selection
    log_info ""

    # Step 2: Target disk selection
    if ! disk_selection; then
        log_error "Disk selection failed or was canceled"
        return 1
    fi
    log_info ""

    # Step 3: Mode-specific configuration
    # Dispatch to the appropriate configuration function based on install mode
    if [[ "${SETUP_DISK_PREFERENCES[install_mode]}" == "$DISK_MODE_CLEAR" ]]; then
        configure_clear_install
    elif [[ "${SETUP_DISK_PREFERENCES[install_mode]}" == "$DISK_MODE_NEIGHBOR" ]]; then
        configure_neighbor_install
    else
        # This should never happen if install_mode_selection works correctly
        log_error "Unknown installation mode: ${SETUP_DISK_PREFERENCES[install_mode]}"
        return 1
    fi
    log_info ""

    # Last step for config generation 
    init_setup_disk_conf
}

disk_prepare_for_nixos_install() {
    local target_disk="/dev/${SETUP_DISK_PREFERENCES[target_disk]}"
    local install_mode="${SETUP_DISK_PREFERENCES[install_mode]}"

    if [[ "$install_mode" == "$DISK_MODE_CLEAR" ]]; then
        log_warning "Destructive action: Disk '${target_disk}' will be completely wiped, partitioned, and formatted. Afterwards, it will be mounted at '/mnt'."
        sudo nix run github:nix-community/disko -- --mode destroy,format,mount /tmp/disko.nix
        
    elif [[ "$install_mode" == "$DISK_MODE_NEIGHBOR" ]]; then
        log_info "Non-destructive mode: Existing partitions on '${target_disk}' will be mounted at '/mnt' without any formatting."
        sudo nix run github:nix-community/disko -- --mode mount /tmp/disko.nix
        
    else
        # Added expected values to the error message for easier debugging
        log_error "Unknown installation mode: '${install_mode}'. Expected either '${DISK_MODE_CLEAR}' or '${DISK_MODE_NEIGHBOR}'."
        return 1
    fi

    # Output lsblk information line by line through log_info
    log_info "Current partition layout for '${target_disk}':"
    while IFS= read -r line; do
        log_info "$line"
    done < <(lsblk "$target_disk")
}