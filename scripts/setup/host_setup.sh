#!/usr/bin/env bash
# ============================================================================
# host_setup.sh
# ----------------------------------------------------------------------------
# Purpose:
#   Interactively collects basic host preferences (hostname, username,
#   network name, timezone) from the user, validates them, and generates
#   a NixOS-compatible `preferences` block to be injected into the final
#   configuration.nix.
#
# Workflow:
#   1. Prompts the user for each preference sequentially.
#   2. Validates input using regex or system utilities (timedatectl).
#   3. Auto-detects timezone via an external API if requested and connected.
#   4. Generates a formatted Nix attribute set block.
#   5. Sets global variables (SETUP_USER_HOST_DIR, SETUP_HOST_PREFERENCES)
#      for downstream scripts (e.g., the configuration generator).
#
# Dependencies:
#   - utils.sh      (logging helpers: log_info, log_warning, log_success, log_error)
#   - guard_run     (idempotency guard)
#   - External:     timedatectl, curl, jq (for timezone auto-detection)
#
# Expected external globals:
#   - SETUP_NIXOS_DIR           (root directory of the NixOS flake)
#   - SETUP_IS_NETWORK_CONNECTED ("true" or "false", set by network checks)
# ============================================================================

# ----------------------------------------------------------------------------
# Bootstrap: load shared utilities and activate the run guard.
# `guard_run` ensures the script is not executed/sourced twice in the same
# shell session, which is important because it mutates global state.
# ----------------------------------------------------------------------------
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/utils.sh"
guard_run "${BASH_SOURCE[0]}" "${0}"

# ============================================================================
# Configuration variables
# ----------------------------------------------------------------------------
# Global state populated during the interactive setup. Downstream scripts
# (like the configuration generator) rely on these globals.
# ============================================================================

# Associative array holding the actual values entered by the user.
declare -A SETUP_PREFERENCES=(
    [user.name]="",
    [host.name]="",
    [network.host.name]=""
    [time.timeZone]=""
)

# Human-readable descriptions for each preference (currently unused in this
# script but available for help menus or UI generation). Marked readonly to
# prevent accidental modification during the setup flow.
declare -A SETUP_PREFERENCES_DESCRIPTION=(
    [user.name]="User name for this machine.",
    [host.name]="Host name for this machine.",
    [network.host.name]="Network name for this machine."
    [time.timeZone]="Time zone for this machine."
)
readonly SETUP_PREFERENCES_DESCRIPTION

# Directory that will be generated based on the selected hostname.
# Example: SETUP_USER_HOST_DIR="${SETUP_NIXOS_DIR}/hosts/my-laptop"
SETUP_USER_HOST_DIR=""

# Generated NixOS attribute set block containing the preferences.
# Injected directly into configuration.nix by the generator script.
SETUP_HOST_PREFERENCES=""

# ============================================================================
# Validation utilities
# ----------------------------------------------------------------------------
# Pure functions that return 0 (true) on valid input and 1 (false) otherwise.
# Used as callbacks by `read_validated_input`.
# ============================================================================

# validate_hostname <name>
# ----------------------------------------------------------------------------
# Validates a hostname according to RFC 1123:
# - 1-63 characters long
# - contains only letters, digits, and hyphens
# - cannot start or end with a hyphen
#
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
validate_hostname() {
    local name="$1"
    local pattern='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    [[ "$name" =~ $pattern ]]
}

# validate_username <name>
# ----------------------------------------------------------------------------
# Validates a standard Linux username:
# - 1-32 characters long
# - must start with a letter or underscore
# - contains only letters, digits, hyphens, and underscores
#
# Returns: 0 if valid, 1 if invalid.
# ============================================================================
validate_username() {
    local name="$1"
    local pattern='^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$'
    [[ "$name" =~ $pattern ]]
}

# validate_timezone <tz>
# ----------------------------------------------------------------------------
# Validates an IANA timezone string (e.g., "Europe/Moscow") against the
# system's known timezones.
#
# Implementation detail:
# Caches the output of `timedatectl list-timezones` in a hidden global
# variable `_VALID_TIMEZONES_CACHE` to avoid shelling out on every single
# retry, which significantly speeds up the validation loop.
#
# Returns: 0 if valid, 1 if invalid or empty.
# ============================================================================
validate_timezone() {
    local tz="$1"

    if [[ -z "$tz" ]]; then
        log_warning "Timezone cannot be empty."
        return 1
    fi

    # Populate cache on first run
    if [[ -z "${_VALID_TIMEZONES_CACHE[*]:-}" ]]; then
        _VALID_TIMEZONES_CACHE=$(timedatectl list-timezones 2>/dev/null)
    fi

    # Exact line match against the cached timezone list
    if echo "$_VALID_TIMEZONES_CACHE" | grep -Fxq "$tz"; then
        return 0
    fi

    log_warning "Unknown timezone: '$tz'."
    return 1
}

# ============================================================================
# Input reading functions with retry on invalid input
# ============================================================================

# read_validated_input <key> <prompt> <validator_func>
# ----------------------------------------------------------------------------
# Prompts the user for a value, strips spaces, and validates it using the
# provided callback function. Loops indefinitely until a valid, non-empty
# value is provided.
#
# Arguments:
#   $1 - key           : the key in SETUP_PREFERENCES to populate
#   $2 - prompt        : the text to display to the user
#   $3 - validator     : name of the validation function to call
#
# Side effects:
#   Updates SETUP_PREFERENCES[$key] with the validated value.
# Returns: 0 on success (always returns 0 eventually, as it loops).
# ============================================================================
read_validated_input() {
    local key="$1"
    local prompt="$2"
    local validator="$3"
    local value

    while true; do
        read -r -p "$prompt" value
        value="${value// /}"  # strip spaces

        if [[ -z "$value" ]]; then
            log_warning "Value cannot be empty."
            continue
        fi

        # Execute the validator callback. If it returns 0 (success), we are done.
        if $validator "$value"; then
            SETUP_PREFERENCES["$key"]="$value"
            return 0
        else
            log_warning "Invalid value: '$value'. Please try again."
        fi
    done
}


# ============================================================================
# Concrete preferences setup functions
# ----------------------------------------------------------------------------
# High-level wrappers around `read_validated_input` that handle the specific
# logic, prompts, and fallbacks for each individual preference.
# ============================================================================

# host_name_setup
# ----------------------------------------------------------------------------
# Prompts for and validates the machine's hostname.
#
# Side effects:
#   Sets SETUP_PREFERENCES[host.name] to the validated hostname.
#
# Returns: 0 on success (always returns 0, as read_validated_input loops).
# ============================================================================
host_name_setup() {
    read_validated_input "host.name" \
        "Enter hostname (e.g., my-laptop): " \
        validate_hostname
    log_info "Hostname: ${SETUP_PREFERENCES[host.name]}"
}

# user_name_setup
# ----------------------------------------------------------------------------
# Prompts for and validates the primary user's username.
#
# Side effects:
#   Sets SETUP_PREFERENCES[user.name] to the validated username.
#
# Returns: 0 on success (always returns 0, as read_validated_input loops).
# ============================================================================
user_name_setup() {
    read_validated_input "user.name" \
        "Enter username: " \
        validate_username
    log_info "Username: ${SETUP_PREFERENCES[user.name]}"
}

# network_host_name_setup
# ----------------------------------------------------------------------------
# Prompts for the network name (used for networking/mDNS). Offers a
# recommended default that matches the machine's hostname, but allows
# a custom entry which goes through standard hostname validation.
#
# Side effects:
#   Sets SETUP_PREFERENCES[network.host.name] to the selected value.
#
# Returns: 0 on success (always returns 0, as it loops until valid choice).
# ============================================================================
network_host_name_setup() {
    log_info ""
    log_info "Select network name:"
    log_info "  1) Same as hostname: '${SETUP_PREFERENCES[host.name]}' (recommended)"
    log_info "  2) Enter custom name"
    while true; do
        read -r -p "Your choice [1/2]: " choice
        case "$choice" in
            1)
                SETUP_PREFERENCES[network.host.name]="${SETUP_PREFERENCES[host.name]}"
                break
                ;;
            2)
                read_validated_input "network.host.name" \
                    "Enter network name: " \
                    validate_hostname
                break
                ;;
            *)
                log_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    log_info "Network name: ${SETUP_PREFERENCES[network.host.name]}"
}

# time_timeZone_setup
# ----------------------------------------------------------------------------
# Configures the system timezone. Offers two methods:
#   1) Auto-detection via ipinfo.io (requires active network connection).
#   2) Manual entry, validated against the system's timezone database.
#
# Implementation detail:
#   Uses `jq -r` (raw output) to extract the timezone string without JSON
#   quotes, ensuring the value is a plain string like "Asia/Novosibirsk".
#
# Side effects:
#   Sets SETUP_PREFERENCES[time.timeZone] to the selected timezone.
#
# Returns: 0 on success (always returns 0, as it loops until valid choice).
# ============================================================================
time_timeZone_setup() {
    log_info ""
    log_info "=== Timezone Configuration ==="
    log_info "Select timezone configuration method:"
    log_info "  1) Auto-detect (recommended, requires network connection)"
    log_info "  2) Manual entry (e.g., Europe/Moscow, America/New_York)"
    log_info ""
    while true; do
        read -r -p "Your choice [1/2]: " choice
        case "$choice" in
            1)
                # Guard against auto-detection if the network check failed earlier
                if [[ "${SETUP_IS_NETWORK_CONNECTED}" == "false" ]]; then
                    log_error "Network is not connected. Please use option 2 for manual configuration."
                    continue
                fi

                # Fetch timezone from external IP geolocation API and parse with jq
                # Using -r flag to get raw string output without JSON quotes
                SETUP_PREFERENCES[time.timeZone]=$( curl -s https://ipinfo.io/json | jq -r '.timezone' )
                log_success "Timezone auto-detected: ${SETUP_PREFERENCES[time.timeZone]}"
                break
                ;;
            2)
                read_validated_input  "time.timeZone" \
                    "Enter timezone (e.g., Asia/Novosibirsk): " \
                    "validate_timezone"
                log_success "Timezone set to: ${SETUP_PREFERENCES[time.timeZone]}"
                break
                ;;
            *)
                log_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    log_info "timezone: ${SETUP_PREFERENCES[time.timeZone]}"
}

# ============================================================================
# Nix configuration generation
# ============================================================================

# generate_preferences_block <prefs_array_name>
# ----------------------------------------------------------------------------
# Converts an associative array of preferences into a formatted Nix attribute
# set block (string) ready to be injected into configuration.nix.
#
# Arguments:
#   $1 - prefs_ref : name of the associative array to read (passed by nameref)
#
# Returns:
#   Prints the formatted Nix block to stdout.
#
# Implementation detail:
#   Uses `sort` on the keys to ensure deterministic, reproducible output
#   regardless of bash's internal hash table ordering.
#
# Example output:
#   preferences = {
#     host.name = "my-laptop";
#     network.host.name = "my-laptop";
#     time.timeZone = "Asia/Novosibirsk";
#     user.name = "daniil";
#   };
# ============================================================================
generate_preferences_block() {
    # `local -n` creates a nameref, allowing us to pass an associative array
    # by reference rather than by value.
    local -n prefs_ref="$1"
    local output="preferences = {\n"

    # Sort keys for deterministic output
    local sorted_keys
    IFS=$'\n' sorted_keys=($(sort <<<"${!prefs_ref[*]}")); unset IFS

    for key in "${sorted_keys[@]}"; do
        local value="${prefs_ref[$key]}"
        # Wrap values in quotes for valid Nix syntax
        output+="        ${key} = \"${value}\";\n"
    done
    output+="      };"

    echo -e "$output"
}

# show_setuped_preferences
# ----------------------------------------------------------------------------
# Pretty-prints the currently collected SETUP_PREFERENCES to the terminal
# using the logging utility. Used by the configuration summary screen.
#
# Implementation detail:
# Keys are sorted for deterministic display order.
#
# Side effects:
#   Prints formatted output to stdout via log_info.
# ============================================================================
show_setuped_preferences() {
    local -n prefs_ref="SETUP_PREFERENCES"

    # Sort keys for deterministic output
    local sorted_keys
    IFS=$'\n' sorted_keys=($(sort <<<"${!prefs_ref[*]}")); unset IFS

    for key in "${sorted_keys[@]}"; do
        local value="${prefs_ref[$key]}"
        log_info "  - ${key} = ${value}"
    done
}

# ============================================================================
# Main host setup function
# ============================================================================

# host_setup
# ----------------------------------------------------------------------------
# Top-level entry point for the interactive host configuration phase.
#
# Orchestrates the collection of all host-specific preferences, generates
# the final Nix preferences block, and determines the filesystem path
# where the host's configuration will reside.
#
# Workflow:
#   1. Prompts for hostname (validated per RFC 1123)
#   2. Prompts for username (validated per Linux username rules)
#   3. Prompts for network name (defaults to hostname)
#   4. Prompts for timezone (auto-detect or manual entry)
#   5. Generates Nix preferences block from collected values
#   6. Computes target directory path based on hostname
#
# Globals written:
#   SETUP_PREFERENCES       - populated with user inputs
#   SETUP_HOST_PREFERENCES  - generated Nix code block
#   SETUP_USER_HOST_DIR     - target directory for the host config
#
# Returns: 0 on success.
# ============================================================================
host_setup() {
    log_info "========================================="
    log_info "             NixOS Host Setup            "
    log_info "========================================="

    host_name_setup
    user_name_setup
    network_host_name_setup
    time_timeZone_setup

    # Generate the Nix code block from the collected preferences
    SETUP_HOST_PREFERENCES="$( generate_preferences_block SETUP_PREFERENCES )"

    # Build the host directory path based on the selected hostname.
    # Assumes SETUP_NIXOS_DIR is defined in the environment (e.g., by the main installer script).
    SETUP_USER_HOST_DIR="${SETUP_NIXOS_DIR}/hosts/${SETUP_PREFERENCES[host.name]}"
    log_info "Host directory: $SETUP_USER_HOST_DIR"
}
