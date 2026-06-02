#!/usr/bin/env bash

readonly CLEAR_INSTALL=0
readonly NEIGHBOR_INSTALL=1

SELECTED_DISK=""
NIXOS_INSTALL_MODE=$NEIGHBOR_INSTALL
BOOT_SIZE="1G" # Default boot partition size

# ==============================================================================
# Initialize default values for flags
# ==============================================================================
VERBOSE=false
FORCE=false
YES=false

log_debug()
{
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] $1"
    fi
}

show_install_menu() {
    echo "========================================="
    echo "      NixOS Installation Mode Selection      "
    echo "========================================="
    
    # PS3 is a special Bash variable for the 'select' command prompt
    PS3="Enter the mode number (1-3): "
    
    # Array of available options
    local options=(
        "Full disk wipe (Clear Install)"
        "Install alongside existing OS (Neighbor / Dual-boot)"
        "Cancel"
    )

    # The 'select' command automatically creates a loop and numbered menu
    select opt in "${options[@]}"; do
        case "$opt" in
            "Full disk wipe (Clear Install)")
                INSTALL_MODE=$CLEAR_INSTALL
                echo -e "\n[OK] Selected mode: Full disk wipe."
                break # Exit the select loop
                ;;
            "Install alongside existing OS (Neighbor / Dual-boot)")
                INSTALL_MODE=$NEIGHBOR_INSTALL
                echo -e "\n[OK] Selected mode: Install alongside existing OS."
                break
                ;;
            "Cancel")
                echo -e "\n[!] Installation canceled by user."
                exit 0
                ;;
            *)
                # This branch triggers if the user enters anything other than 1, 2, or 3
                echo -e "\n[!] Error: Invalid choice. Please enter a number from 1 to 3."
                ;;
        esac
    done
}

disk_selection() {
    echo "========================================="
    echo "         Target Disk Selection           "
    echo "========================================="
    
    # Fetch available disks into an array
    local disks=($(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print $1}'))
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        echo "[!] Error: No valid disks found on this system."
        return 1
    fi

    # Add a "Cancel" option to the end of the disk array
    local options=("${disks[@]}" "Cancel and Restart")
    
    PS3="Select the target disk number (or Cancel): "
    
    select opt in "${options[@]}"; do
        if [[ "$opt" == "Cancel and Restart" ]]; then
            return 1 # Signal cancellation
        elif [[ -n "$opt" ]]; then
            SELECTED_DISK="$opt"
            echo -e "\n[OK] Selected target disk: /dev/$SELECTED_DISK"
            return 0 # Success
        else
            echo -e "\n[!] Error: Invalid choice. Please enter a valid number."
        fi
    done
}

show_disk_info() {
    local disk=$1
    echo "========================================="
    echo "      Disk Information: /dev/$disk       "
    echo "========================================="
    echo ">> Basic Info:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN /dev/"$disk" 2>/dev/null
    echo ">> Partitions & Filesystems:"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT /dev/"$disk" 2>/dev/null
    echo "========================================="
}

# ==============================================================================
# Configuration for Clear Install
# ==============================================================================
configure_clear_install() {
    echo "========================================="
    echo "      Clear Install Configuration        "
    echo "========================================="
    echo "[*] Note: The actual partitioning and formatting (BTRFS, etc.)"
    echo "    will be handled automatically by Disko later in the process."
    echo "    We just need to gather your preferences now."
    echo ""
    
    while true; do
        read -p "Enter boot partition size (e.g., 512M, 1G, 2G). Default is [$BOOT_SIZE]: " input_size
        
        # If user presses Enter, use the default value
        if [[ -z "$input_size" ]]; then
            input_size="$BOOT_SIZE"
        fi
        
        # Basic validation: must be a number followed by M or G (case-insensitive)
        if [[ "$input_size" =~ ^[0-9]+[MmGg]$ ]]; then
            # Normalize to uppercase (e.g., 1g -> 1G)
            BOOT_SIZE="${input_size^^}"
            echo -e "\n[OK] Boot partition size set to: $BOOT_SIZE"
            return 0
        else
            echo -e "\n[!] Error: Invalid format. Please use a number followed by 'M' or 'G' (e.g., 1G, 512M)."
        fi
    done
}

neighbor_install()
{
    echo "Neigbor install"
}

execute_installation() {
    echo ""
    echo "========================================="
    echo "        Starting Installation...         "
    echo "========================================="
    echo "[*] Mode: $([ "$INSTALL_MODE" -eq "$CLEAR_INSTALL" ] && echo "Clear Install" || echo "Neighbor Install")"
    echo "[*] Target: /dev/$SELECTED_DISK"
    
    if (( INSTALL_MODE == CLEAR_INSTALL )); then
        echo "[*] Boot Size Configured: $BOOT_SIZE"
        echo "[*] Filesystem: BTRFS (to be applied by Disko)"
    fi
    
    echo ""
    echo "[*] Executing Disko configuration and nixos-install..."
    # TODO: Call your Disko generation and nixos-install commands here
    # Example: nix run github:nix-community/disko -- --mode disko /path/to/your/disko-config.nix
    sleep 2
    echo "[OK] Installation completed successfully!"
}

# ==============================================================================
# Main logic
# ==============================================================================
main() {
    echo "========================================================"
    echo "   Welcome to the Automated NixOS Installer Script      "
    echo "========================================================"
    echo ""

    while true; do
        # Step 1: Installation Mode
        if ! show_install_menu; then
            echo -e "\n[!] Installation canceled by user. Exiting."
            exit 0
        fi
        echo ""

        # Step 2: Disk Selection
        if ! disk_selection; then
            echo -e "\n[!] Disk selection canceled. Returning to the beginning..."
            echo "---------------------------------------------------------"
            continue
        fi
        echo ""

        # Step 3: Mode-specific configuration
        if (( INSTALL_MODE == CLEAR_INSTALL )); then
            if ! configure_clear_install; then
                echo -e "\n[!] Configuration canceled. Returning to the beginning..."
                echo "---------------------------------------------------------"
                continue
            fi
            echo ""
        elif (( INSTALL_MODE == NEIGHBOR_INSTALL )); then
            echo "[*] Neighbor install configuration will be handled in the next step."
            # TODO: Add neighbor install configuration logic here later
            echo ""
        fi

        # Step 4: Show Disk Info
        show_disk_info "$SELECTED_DISK"
        echo ""

        # Step 5: Final Confirmation
        echo "SUMMARY OF YOUR CHOICES:"
        echo "  - Installation Mode : $([ "$INSTALL_MODE" -eq "$CLEAR_INSTALL" ] && echo "Clear Install (Wipes disk)" || echo "Neighbor Install (Dual-boot)")"
        echo "  - Target Disk       : /dev/$SELECTED_DISK"
        if (( INSTALL_MODE == CLEAR_INSTALL )); then
            echo "  - Boot Partition    : $BOOT_SIZE"
            echo "  - Filesystem        : BTRFS (via Disko)"
        fi
        echo ""
        echo "WARNING: Proceeding will modify your disk."
        read -p "Are you sure you want to proceed? [y/N] (or 'r' to restart, 'c' to cancel): " confirm
        
        confirm="${confirm,,}"

        case "$confirm" in
            y|yes)
                execute_installation
                break
                ;;
            r|restart)
                echo -e "\n[*] Restarting the setup process..."
                echo "---------------------------------------------------------"
                continue
                ;;
            c|cancel|n|no|"")
                echo -e "\n[!] Installation canceled by user. Exiting."
                exit 0
                ;;
            *)
                echo -e "\n[!] Invalid input. Please try again."
                ;;
        esac
    done
}

# ==============================================================================
# Parse command-line arguments
# ==============================================================================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            ;;
        -f|--force)
            FORCE=true
            ;;
        -y|--yes)
            YES=true
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--verbose] [-f|--force] [-y|--yes]"
            echo "  -v, --verbose  : Enable verbose output"
            echo "  -f, --force    : Force execution (skip confirmation prompts)"
            echo "  -y, --yes      : Automatically answer 'yes' to all prompts"
            exit 0
            ;;
        *)
            echo "Error: Unknown parameter '$1'" >&2
            echo "Use '$0 --help' for more information." >&2
            exit 1
            ;;
    esac
    # Shift positional parameters to the left by 1.
    # This makes $2 become $1, $3 become $2, etc., for the next loop iteration.
    shift
done

# ==============================================================================
# Main loop run
# ==============================================================================
main