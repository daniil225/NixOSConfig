#!/usr/bin/env bash
# ============================================================================
# utils.sh — Core utilities library for the NixOS installer
# ----------------------------------------------------------------------------
# Purpose:
#   Provides shared utilities used by all installer scripts:
#     - Logging system with color support and configurable verbosity
#     - Network connectivity check
#     - Execution guards to prevent double-loading and direct execution
#
# This file is designed to be sourced (not executed directly) by other scripts.
# It includes a guard to prevent multiple inclusions in the same shell session.
#
# Usage:
#   source /path/to/utils.sh
#
# Features:
#   - Colored log output (can be disabled via SETUP_ENABLE_LOG_COLOR)
#   - Optional log level prefixes (via SETUP_SHOW_TYPE_INFO)
#   - Debug mode (via SETUP_DEBUG)
#   - Non-interactive mode flag (SETUP_YES)
# ============================================================================

# ============================================================================
# Include guard
# ----------------------------------------------------------------------------
# Prevents this file from being sourced multiple times in the same shell session.
# This is important because utils.sh defines global state (colors, log functions)
# that should only be initialized once.
#
# Mechanism:
#   - Checks if __UTILS_SH_LOADED__ is already set
#   - If yes, returns immediately (return 0 for sourced files, exit 0 as fallback)
#   - If no, sets the flag as readonly to prevent modification
# ============================================================================
if [[ -n "${__UTILS_SH_LOADED__:-}" ]]; then return 0 2>/dev/null || exit 0; fi
readonly __UTILS_SH_LOADED__=1

# ============================================================================
# ANSI color codes
# ----------------------------------------------------------------------------
# Standard ANSI escape sequences for terminal colors.
# Format: \033[<code>m where <code> is the color attribute.
# These are used by the logging system to colorize output.
# ============================================================================

readonly RED='\033[0;31m'         # Red for errors
readonly YELLOW='\033[0;33m'      # Yellow for warnings
readonly GREEN='\033[0;32m'       # Green for success messages
readonly BLUE='\033[0;34m'        # Blue for info messages
readonly GRAY='\033[0;90m'        # Gray for debug messages
readonly NC='\033[0m'             # Reset to default color (No Color)

# ============================================================================
# Log level configuration
# ----------------------------------------------------------------------------
# Two-tier system:
#   - LOG_COLORS:    maps log level to ANSI color code
#   - LOG_PREFIXES:  maps log level to text prefix (e.g., "[ERROR]:")
#
# Both are readonly to prevent accidental modification during runtime.
# ============================================================================

declare -A LOG_COLORS=(
    [error]=$RED
    [warning]=$YELLOW
    [info]=$BLUE
    [success]=$GREEN
    [debug]=$GRAY
)
readonly LOG_COLORS

declare -A LOG_PREFIXES=(
    [error]="[ERROR]:"
    [warning]="[WARNING]:"
    [info]="[INFO]:"
    [success]="[SUCCESS]:"
    [debug]="[DEBUG]:"
)
readonly LOG_PREFIXES

# ============================================================================
# Configuration parameters
# ----------------------------------------------------------------------------
# Global flags that control logging behavior. These can be set by the main
# installer script (install.sh) via CLI arguments, or toggled programmatically
# using the enable/disable functions below.
# ============================================================================

# Enable debug-level log messages (default: disabled)
SETUP_DEBUG=false

# Show log level prefixes like "[INFO]:" before each message (default: hidden)
SETUP_SHOW_TYPE_INFO=false

# Enable ANSI color codes in log output (default: enabled)
SETUP_ENABLE_LOG_COLOR=true

# Non-interactive mode: auto-confirm all prompts (default: interactive)
SETUP_YES=false

# ============================================================================
# Configuration toggle functions
# ----------------------------------------------------------------------------
# Simple setters for the configuration flags above. Provided for convenience
# so that other scripts can toggle features without directly modifying globals.
# ============================================================================

# Enable log level prefixes in output
enable_show_type_info() {
    SETUP_SHOW_TYPE_INFO=true
}

# Disable log level prefixes in output
disable_show_type_info() {
    SETUP_SHOW_TYPE_INFO=false
}

# Enable ANSI color codes in log output
enable_log_color() {
    SETUP_ENABLE_LOG_COLOR=true
}

# Disable ANSI color codes in log output
disable_log_color() {
    SETUP_ENABLE_LOG_COLOR=false
}

# Enable debug-level logging
enable_debug() {
    SETUP_DEBUG=true
}

# Disable debug-level logging
disable_debug() {
    SETUP_DEBUG=false
}

# ============================================================================
# Core logging function
# ============================================================================

# log <msg_type> <message...>
# ----------------------------------------------------------------------------
# Central logging function that handles all log output.
#
# Arguments:
#   $1       - msg_type : log level (error, warning, info, success, debug)
#   $2...    - message  : the message to log (all remaining args are joined)
#
# Behavior:
#   - If msg_type is "debug" and SETUP_DEBUG is false, returns immediately
#   - Applies color codes if SETUP_ENABLE_LOG_COLOR is true
#   - Prepends log level prefix if SETUP_SHOW_TYPE_INFO is true
#   - Outputs the formatted message to stdout
#
# Implementation detail:
#   Uses `echo -e` to interpret ANSI escape sequences. The color and prefix
#   are conditionally applied based on the configuration flags.
# ============================================================================
log()
{
    local msg_type="$1"
    shift
    local message="$*"

    # Skip debug messages if debug mode is disabled
    [[ "$msg_type" == "debug" && "$SETUP_DEBUG" == "false" ]] && return 0

    # Look up color and prefix for this log level
    local color="${LOG_COLORS[$msg_type]}"
    local prefix="${LOG_PREFIXES[$msg_type]}"
    local show_prefix="$SETUP_SHOW_TYPE_INFO"
    local show_color="$SETUP_ENABLE_LOG_COLOR"

    # Build the final output components
    local final_prefix=""
    local final_color=""
    local final_reset=""

    # Conditionally apply prefix
    [[ "$show_prefix" == "true" ]] && final_prefix="${prefix} "
    
    # Conditionally apply color and reset code
    [[ "$show_color" == "true" ]] && { final_color="${color}"; final_reset="${NC}"; }
    
    # Output the formatted message
    echo -e "${final_color}${final_prefix}${message}${final_reset}"
}

# ============================================================================
# Log level wrappers
# ----------------------------------------------------------------------------
# Convenience functions for each log level. These simply delegate to log()
# with the appropriate msg_type, making the calling code more readable.
# ============================================================================

log_error()   { log "error" "$@"; }
log_warning() { log "warning" "$@"; }
log_info()    { log "info" "$@"; }
log_success() { log "success" "$@"; }
log_debug()   { log "debug" "$@"; }

# ============================================================================
# System utilities
# ============================================================================

# check_network_connection
# ----------------------------------------------------------------------------
# Checks if the system has an active network connection (WiFi or Ethernet).
#
# Implementation:
#   Uses `nmcli connection show --active` to list active NetworkManager connections,
#   then parses the output with awk to check if any connection has type "wifi" or "ethernet".
#
# Returns:
#   Prints "true" if an active connection is found, "false" otherwise.
#
# Usage:
#   if [[ "$(check_network_connection)" == "true" ]]; then
#       # network is available
#   fi
#
# Note:
#   This function is typically called once at script startup and the result
#   is cached in SETUP_IS_NETWORK_CONNECTED to avoid repeated checks.
# ============================================================================
check_network_connection() {
    nmcli connection show --active | awk '
        BEGIN {
            conn = 0
        }
        { 
            # Column 3 contains the connection type (wifi, ethernet, etc.)
            if($3 == "wifi" || $3 == "ethernet") {
                conn = 1;
            }
        }
        END {
            if(conn == 1) { print "true" }
            else { print "false" }
        }
    '
}

# ============================================================================
# Execution guards
# ============================================================================

# guard_run <bash_source> <run_script>
# ----------------------------------------------------------------------------
# Prevents library scripts from being executed directly (instead of sourced).
#
# Arguments:
#   $1 - bash_source : value of ${BASH_SOURCE[0]} (the file being sourced)
#   $2 - run_script  : value of ${0} (the script that was executed)
#
# Logic:
#   If BASH_SOURCE[0] == $0, it means the file was executed directly rather
#   than sourced. This is an error for library files like utils.sh, which
#   are meant to be sourced by other scripts.
#
# Usage (at the end of a library file):
#   guard_run "${BASH_SOURCE[0]}" "${0}"
#
# Note:
#   This function logs an error but does NOT exit, allowing the calling script
#   to decide how to handle the error. Most scripts will follow this with
#   an explicit exit if needed.
# ============================================================================
guard_run() {
    local bash_src="${1}"
    local run_script="${2}"

    # If the sourced file is the same as the executed script, it's a direct run
    if [[ "${bash_src}" == "${run_script}" ]]; then
        log_error "File: ${run_script} use like only the lib via source in main script, not the forward run"
    fi
}

# ============================================================================
# Self-protection
# ============================================================================
# Apply the guard to utils.sh itself to prevent direct execution.
# This ensures utils.sh can only be used when sourced by another script.
# ============================================================================
guard_run "${BASH_SOURCE[0]}" "${0}"