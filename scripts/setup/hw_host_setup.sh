#!/usr/bin/env bash
# ============================================================================
# hw_conf_gen.sh — Hardware configuration generator for NixOS installation
# ----------------------------------------------------------------------------
# Purpose:
#   Generates hardware-configuration.nix by running nixos-generate-config
#   on the mounted target system (/mnt), then extracts the relevant hardware
#   configuration block for injection into the final flake module.
#
# Workflow:
#   1. Runs nixos-generate-config on the mounted system to auto-detect hardware
#   2. Parses the generated hardware-configuration.nix file
#   3. Extracts the inner configuration block (excluding the outer wrapper)
#   4. Stores the result in SETUP_HW_HOST_CONFIG for later use
#
# Prerequisites:
#   - Target system must be mounted at /mnt
#   - Disk setup must be completed before running this script
#   - nixos-generate-config must be available (provided by NixOS installer)
#
# Dependencies:
#   - utils.sh              (logging helpers: log_info, log_warning, log_error)
#   - guard_run             (idempotency guard)
#   - nixos-generate-config (NixOS hardware detection tool)
#   - awk                   (for parsing the generated configuration)
#
# Globals written:
#   - SETUP_HW_HOST_CONFIG  (extracted hardware configuration block)
# ============================================================================

# ----------------------------------------------------------------------------
# Prerequisite note
# ----------------------------------------------------------------------------
# This script must be run AFTER disk setup is completed and the target
# filesystem is mounted at /mnt. Running it before mounting will fail.
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Bootstrap: load shared utilities and activate the run guard.
# ----------------------------------------------------------------------------
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/utils.sh"
guard_run "${BASH_SOURCE[0]}" "${0}"

# Global variable to hold the extracted hardware configuration block.
# This will be injected into the hardware-configuration.nix template by
# the configuration generator (configuration_generator.sh).
SETUP_HW_HOST_CONFIG=""

# ============================================================================
# Hardware configuration parser
# ============================================================================

# get_hw_host_config <file>
# ----------------------------------------------------------------------------
# Parses a hardware-configuration.nix file and extracts the inner configuration
# block, excluding the outer flake module wrapper.
#
# Arguments:
#   $1 - file : path to the hardware-configuration.nix file to parse
#
# Returns:
#   0 on success, prints the extracted configuration block to stdout
#   1 if the file does not exist
#
# Implementation detail:
#   Uses awk to track brace depth and extract content between the first
#   opening brace at depth 0 and its matching closing brace. This effectively
#   strips the outer flake module wrapper:
#
#   Input:
#     {
#       imports = [ ... ];
#       fileSystems = { ... };
#       ...
#     }
#
#   Output:
#     imports = [ ... ];
#     fileSystems = { ... };
#     ...
#
#   The awk logic:
#   - When encountering '{' at the start of a line, increment depth counter
#   - When encountering '}' at the start of a line, check if we're at depth 1
#     (inner block), and if so, exit (stop printing)
#   - Print all lines when depth counter is 1 (inside the outer braces)
# ============================================================================
get_hw_host_config() {
	local file="${1}" # path to hardware-configuration.nix
	
	# Validate file existence
	if [[ ! -f "$file" ]]; then
		log_error "File not found: $file"
		return 1
	fi

	local out
	# Extract the inner configuration block using awk
	# This strips the outer flake module wrapper { ... }
	out=$(awk '/^[[:space:]]*{$/{c++; next} /^[[:space:]]*}$/{if(c==1) exit} c==1' "$file")

	echo -e "${out}"
}


# ============================================================================
# Main hardware setup function
# ============================================================================

# hw_host_setup
# ----------------------------------------------------------------------------
# Top-level orchestrator for hardware configuration generation.
#
# Workflow:
#   1. Runs nixos-generate-config on the mounted system (/mnt)
#      - Uses --no-filesystems to avoid conflicts with disko configuration
#      - Generates to /tmp/nixos-config to avoid polluting the target system
#   2. Validates that the generated file exists
#   3. Parses the file to extract the inner configuration block
#   4. Stores the result in SETUP_HW_HOST_CONFIG
#
# Prerequisites:
#   - Target filesystem must be mounted at /mnt
#   - Disk setup must be completed (disko configuration applied)
#
# Side effects:
#   - Creates /tmp/nixos-config directory with generated files
#   - Sets SETUP_HW_HOST_CONFIG global variable
#
# Returns:
#   0 on success
#   1 if nixos-generate-config fails or file is not found
# ============================================================================
hw_host_setup() {
	log_info "========================================="
	log_info "        Hardware Configuration Setup     "
	log_info "========================================="

	# Step 1: Generate initial hardware configuration from the mounted system
	# Using --no-filesystems because disko will handle filesystem configuration
	# separately, and we don't want conflicts between auto-detected and disko configs
	log_info "Generating hardware configuration from /mnt..."
	if ! sudo nixos-generate-config --no-filesystems --root /mnt --dir /tmp/nixos-config; then
		log_error "Failed to generate hardware configuration"
		return 1
	fi

	# Step 2: Validate that the generated file exists
	local hw_conf_file="/tmp/nixos-config/hardware-configuration.nix"
	if [[ ! -f "$hw_conf_file" ]]; then
		log_error "Hardware configuration file not found: $hw_conf_file"
		return 1
	fi

	log_info "Hardware configuration loaded successfully"

	# Step 3: Parse and extract the relevant hardware configuration
	# This strips the outer flake module wrapper to get just the inner config block
	log_info "Parsing hardware configuration..."
	SETUP_HW_HOST_CONFIG=$(get_hw_host_config "$hw_conf_file")

	# Step 4: Validate that we got some content
	if [[ -z "$SETUP_HW_HOST_CONFIG" ]]; then
		log_warning "Hardware configuration appears to be empty or could not be parsed"
	else
		log_info "Hardware configuration processed successfully"
	fi

	log_info "========================================="
}
