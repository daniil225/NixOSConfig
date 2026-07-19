#!/usr/bin/env bash
# ============================================================================
# install.sh — Main entry point for the Automated NixOS Installer
# ----------------------------------------------------------------------------
# Purpose:
#   Orchestrates the full NixOS installation workflow:
#     1. Collects host/user preferences interactively (hostname, username, timezone)
#     2. Lets the user select NixOS modules (base, general, desktop, disko, etc.)
#     3. Generates hardware-configuration.nix from the mounted target system
#     4. Generates configuration.nix for the target host
#     5. (Planned) Configures disk partitioning via disko
#
# Strict mode:
#   -e  : exit immediately on any command failure
#   -u  : treat unset variables as errors
#   -o pipefail : propagate failures through pipes
#   Together these make the script fail fast and loudly on any mistake.
#
# Dependencies:
#   - utils.sh                 (logging helpers, guard_run, network check)
#   - setup/host_setup.sh      (interactive host/user preference collection)
#   - setup/module_setup.sh    (interactive NixOS module selection)
#   - setup/disk_setup.sh      (disk partitioning wizard)
#   - setup/conf_gen.sh        (configuration.nix generator)
#   - setup/hw_host_setup.sh   (hardware-configuration.nix generator)
#
# CLI flags:
#   -d, --debug              Enable debug mode (SETUP_DEBUG=true)
#   --disable-log-color      Disable colored log output
#   --enable-show-log-type   Show log level prefixes (INFO/WARN/...)
#   -y, --yes                Auto-confirm prompts (non-interactive mode)
#   -h, --help               Show help (not yet implemented)
# ============================================================================

set -euo pipefail

# ============================================================================
# Constant parameters
# ----------------------------------------------------------------------------
# These paths are computed once at startup and never change. Marked `readonly`
# to prevent accidental modification by any sourced module.
# ============================================================================

# Absolute path to the directory containing this script.
# Used as the base for resolving all other relative paths.
readonly SETUP_SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# Absolute path to the root of the NixOS flake configuration tree.
# Expected layout: <repo>/nixos/ (contains flake.nix, hosts/, modules/, etc.)
readonly SETUP_NIXOS_DIR="$(realpath "${SETUP_SCRIPT_DIR}/../nixos")"

# Directory where per-host configurations are stored.
# Each host gets its own subdirectory: hosts/<hostname>/
readonly SETUP_NIXOS_HOST_DIR="${SETUP_NIXOS_DIR}/hosts"

# ============================================================================
# Configuration parameters
# ----------------------------------------------------------------------------
# Paths to the files generated during the installation flow. These are
# hw_host_setup.sh) and consumed by downstream steps.
# ============================================================================

# Path to the generated configuration.nix for the target host.
# Set by conf_gen.sh after generating the main host configuration.
SETUP_NIXOS_CONF_FILE=""

# Path to the generated hardware-configuration.nix for the target host.
# Set by hw_host_setup.sh after extracting hardware config from /mnt.
SETUP_NIXOS_HW_CONF_FILE=""

# Path to the generated disko.nix (disk layout) for the target host.
# Set by disko_conf_gen.sh after generating the disk configuration.
SETUP_NIXOS_DISKO_CONF_FILE=""
SETUP_TMP_DISKO_CONF_FILE=""

# Path to the generated home.nix for the target host.
# Set by home-manager generator (not yet implemented).
SETUP_NIXOS_HOME_MANAGER_CONF_FILE=""

# ============================================================================
# Source all sub-modules
# ----------------------------------------------------------------------------
# Loading order matters:
#   1. utils.sh first — provides logging helpers used by every other module.
#   2. Network check — performed once and cached for downstream modules.
#   3. setup/*_setup.sh — interactive wizards that populate SETUP_PREFERENCES,
#      SELECTED_MODULES, etc. (no dependencies between them, but all need utils).
#   4. setup/*_conf_gen.sh — generators that consume the data collected above
#      and write out the final Nix files.
# ============================================================================

# Core utilities: logging, guards, network check, etc.
source "${SETUP_SCRIPT_DIR}/utils.sh"

# One-shot network connectivity check, performed at script startup.
# The result is cached here so downstream modules don't have to re-check.
# Used, for example, by timezone auto-detection in host_setup.sh.
# Note: check_network_connection is defined in utils.sh (sourced above).
readonly SETUP_IS_NETWORK_CONNECTED=$(check_network_connection)

# --- Interactive setup wizards ---
source "${SETUP_SCRIPT_DIR}/setup/host_setup.sh"     # host/user preferences
source "${SETUP_SCRIPT_DIR}/setup/module_setup.sh"   # NixOS module selection
source "${SETUP_SCRIPT_DIR}/setup/disk_setup.sh"     # disk partitioning wizard

# --- Configuration generators ---
source "${SETUP_SCRIPT_DIR}/setup/conf_gen.sh"       # -> hosts/*/configuration.nix
source "${SETUP_SCRIPT_DIR}/setup/hw_host_setup.sh"  # -> hardware config extraction

# ==============================================================================
# Main logic
# ==============================================================================

# main
# ----------------------------------------------------------------------------
# Top-level orchestrator of the installation flow.
# Runs each setup/generation step in sequence.
#
# Workflow:
#   1. host_setup      - collect hostname, username, timezone, etc.
#   2. module_setup    - select NixOS modules to include
#   3. hw_host_setup   - generate hardware-configuration.nix from /mnt
#   4. conf_gen        - generate configuration.nix and hardware-configuration.nix
#   5. (planned) disk_setup - configure disk partitioning via disko
#
# Arguments:
#   $@ : forwarded CLI arguments (currently unused inside main, but kept
#        for future per-step overrides)
# ==============================================================================
main() {
    log_info "========================================================"
    log_info "   Welcome to the Automated NixOS Installer Script      "
    log_info "========================================================"
    log_info ""

    # Step 1: Collect host/user preferences (hostname, username, timezone, ...)
    # This populates SETUP_PREFERENCES and SETUP_USER_HOST_DIR
    host_setup

    # Step : Disk setup Standaolne/Dual boot swap, root fs.
    disk_setup
   
    # Step 2: Let the user select which NixOS modules to include
    # (base, general, desktop, disko, etc.)
    # This populates SETUP_IMPORT_MODULES and SELECTED_MODULES
    module_setup

    # Step 3: Generate hardware configuration from the mounted target system
    # Requires /mnt to be mounted with the target filesystem
    # This populates SETUP_HW_HOST_CONFIG
    hw_host_setup

    # Step 4: Generate configuration.nix and hardware-configuration.nix
    # from the collected preferences and selected modules
    # This writes the final Nix files to hosts/<hostname>/
    conf_gen

    # Step 5: Now, if clear install format disk and mount to /mnt. If neighbor install only mount to /mnt
    disk_prepare_for_nixos_install

    # Step 6: Install the system
    sudo nixos-install --flake "${SETUP_NIXOS_DIR}#${SETUP_PREFERENCES[host.name]}"

    # Step 7: cp NixOS config + git repository initialization. 
}

# ==============================================================================
# Parse command-line arguments
# ==============================================================================
# Standard bash pattern: iterate over positional parameters with `shift`.
# Each recognized flag sets a global variable that downstream modules inspect.
# Unknown flags cause an immediate exit with an error message.
# ==============================================================================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        # Debug mode — enables verbose logging / extra diagnostics
        -d|--debug)
            SETUP_DEBUG=true
            ;;
        # Disable ANSI color codes in log output (useful when piping to files)
        --disable-log-color)
            SETUP_ENABLE_LOG_COLOR=false
            ;;
        # Prefix each log line with its level (INFO / WARN / ERROR / ...)
        --enable-show-log-type)
            SETUP_SHOW_TYPE_INFO=true
            ;;
        # Non-interactive mode: auto-answer "yes" to all confirmation prompts
        -y|--yes)
            YES=true
            ;;
        # Help — currently a stub; will be implemented later
        -h|--help)
            log_warning "Now not implemented"
            ;;
        # Unknown flag — print error to stderr and exit with failure
        *)
            echo "Error: Unknown parameter '$1'" >&2
            echo "Use '$0 --help' for more information." >&2
            exit 1
            ;;
    esac
    # Consume the processed argument and move to the next one
    shift
done

# ==============================================================================
# Entry point
# ==============================================================================
# Forward all original CLI arguments to main(). Although main() doesn't use
# them yet, passing them preserves the option to add per-step flags later
# without changing this call site.
# ==============================================================================
main "$@"
