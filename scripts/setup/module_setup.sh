#!/usr/bin/env bash
# ============================================================================
# module_selector.sh
# ----------------------------------------------------------------------------
# Purpose:
#   Provides an interactive interface for selecting NixOS modules to include
#   in the host configuration. Users can browse available modules, view
#   detailed descriptions, and select multiple modules by number or through
#   the info command.
#
# Workflow:
#   1. Initializes host-dependent module arrays (requires hostname to be set)
#   2. Displays a numbered list of available NixOS modules with short descriptions.
#   3. Enters an interactive command loop where the user can:
#        - Select modules by entering numbers (e.g., "1 2 3")
#        - View detailed info about a module ("i <number>")
#        - List all modules again ("l")
#        - Clear the current selection ("c")
#        - Confirm the selection ("d")
#   4. Validates that all required modules are included (warns but allows override).
#   5. Generates a NixOS `imports = [ ... ];` block from the selected modules.
#   6. Sets global variables for downstream scripts (configuration generator).
#
# Dependencies:
#   - utils.sh  (logging helpers: log_info, log_warning, log_success)
#   - guard_run (idempotency guard)
#   - SETUP_PREFERENCES[host.name] must be set before calling module_setup()
#
# Globals written:
#   - SETUP_IMPORT_MODULES  (generated Nix imports block)
#   - SELECTED_MODULES      (space-separated list of selected module names)
#   - AVAILABLE_MODULES     (associative array of available modules)
#   - MODULE_DETAILS        (associative array of detailed module descriptions)
#   - __REQUIRE_MODULES     (associative array tracking required module selection)
# ============================================================================

# ----------------------------------------------------------------------------
# Bootstrap: load shared utilities and activate the run guard.
# ----------------------------------------------------------------------------
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/utils.sh"
guard_run "${BASH_SOURCE[0]}" "${0}"

# Global variable to hold the generated Nix imports block.
# Will be populated by generate_imports_block() and consumed by the config generator.
SETUP_IMPORT_MODULES=""

# ============================================================================
# Module selector
# ============================================================================
# Two-tier description system:
#   - AVAILABLE_MODULES: short one-liners shown in the main list
#   - MODULE_DETAILS:    multi-line detailed descriptions shown via "info" command
#
# Keys are the actual NixOS module attribute paths (e.g., "self.nixosModules.base").
#
# Required modules tracking:
#   - __REQUIRE_MODULES: associative array that tracks which required modules
#                        have been selected. Values are "true" or "false".
#                        Used to validate that all mandatory modules are included.
# ============================================================================

# ============================================================================
# Host-dependent array initialization
# ============================================================================

# init_host_dependent_arrays
# ----------------------------------------------------------------------------
# Initializes the module-related associative arrays that depend on the hostname.
#
# Why separate initialization?
#   Some module names include the hostname (e.g., "self.diskoConfigurations.host-${hostname}"),
#   so we cannot define these arrays at script load time. They must be initialized
#   after SETUP_PREFERENCES[host.name] is set by host_setup.sh.
#
# Globals created (using declare -gA for global scope):
#   - __REQUIRE_MODULES   : tracks which required modules have been selected
#   - AVAILABLE_MODULES   : short descriptions for the module list
#   - MODULE_DETAILS      : detailed descriptions for the info command
#
# Prerequisites:
#   - SETUP_PREFERENCES[host.name] must be set (by host_setup.sh)
#
# Returns:
#   0 on success
#   1 if host.name is not set
# ============================================================================
init_host_dependent_arrays() {
    local host_name="${SETUP_PREFERENCES[host.name]}"
    if [[ -z "$host_name" ]]; then
        log_error "init_host_dependent_arrays: host.name is not set yet"
        return 1
    fi

    # Required modules tracking array
    # Uses declare -gA to create a global associative array (visible outside this function)
    # Values are initialized to "false" and updated to "true" when the module is selected
    declare -gA __REQUIRE_MODULES=(
        ["self.nixosModules.base"]=false
        ["self.nixosModules.general"]=false
        ["inputs.disko.nixosModules.disko"]=false
        ["self.diskoConfigurations.host-${SETUP_PREFERENCES[host.name]}"]=false
    )

    # Short descriptions (shown in the list)
    declare -gA AVAILABLE_MODULES=(
        ["self.nixosModules.base"]="Host preferences and variables"
        ["self.nixosModules.general"]="General tools and utilities"
        ["self.nixosModules.desktop"]="Desktop environment and applications"
        ["inputs.disko.nixosModules.disko"]="Declarative disk partitioning and formatting engine"
        ["self.diskoConfigurations.host-${SETUP_PREFERENCES[host.name]}"]="Host-specific disk layout and partitioning"
    )

    # Detailed descriptions (shown with 'info' command)
    declare -gA MODULE_DETAILS=(
        ["self.nixosModules.base"]="Host preferences and variables
Defines:
  - preferences.user.name (required)
  - Future: email, locale, timezone, etc.

This module declares options that must be set in your host configuration.
It does NOT configure the system itself — only defines variables for other modules to use.

Required for personalized setup."

        ["self.nixosModules.general"]="Base system configuration
Configures:
  - User account creation (from preferences.user.name)
  - Timezone
  - Locale settings
  - Imports base nix module for work with nix language

This is the foundation that other modules build upon.
Requires: base module.

Required for any NixOS installation."

        ["self.nixosModules.desktop"]="Desktop environment and applications
Includes:
  - GNOME desktop environment
  - Firefox browser
  - Telegram desktop

For graphical desktop usage.
Optional: only required if a graphical interface is needed."

        ["inputs.disko.nixosModules.disko"]="Declarative disk partitioning and formatting engine
Enables the disko NixOS module, which provides:
  - Declarative disk layout definitions
  - Automatic partitioning and formatting during installation
  - Filesystem and mount point generation

This is the underlying engine that processes your disk configurations.
Requires: A specific host disko configuration to define the actual layout.

Mandatory for disk management and installation."

        ["self.diskoConfigurations.host-${SETUP_PREFERENCES[host.name]}"]="Host-specific disk layout and partitioning
Defines the exact disk topology for this specific host:
  - Disk selection and partition schemes (e.g., GPT)
  - Filesystem types (ext4, btrfs, fat32, etc.)
  - Mount points and swap configuration

This configuration is passed to the disko module to format and mount drives.
Requires: The base disko module (inputs.disko.nixosModules.disko).

Mandatory for defining how the host's storage is structured."
    )
}

# ============================================================================
# Display functions
# ============================================================================

# show_module_list
# ----------------------------------------------------------------------------
# Prints a numbered list of all available modules with their short descriptions.
# Also builds a local array (module_list) for index-to-module mapping.
#
# Side effects:
#   - Prints to stdout via log_info
# ============================================================================
show_module_list() {
    local i=1
    local module_list=()
    
    log_info "Available modules:"
    log_info ""
    
    # Iterate over all keys in AVAILABLE_MODULES
    for module in "${!AVAILABLE_MODULES[@]}"; do
        module_list+=("$module")
        log_info "  $i) $module"
        log_info "     ${AVAILABLE_MODULES[$module]}"
        log_info ""
        ((i++))
    done
}

# show_module_info <module>
# ----------------------------------------------------------------------------
# Displays the detailed description for a specific module.
#
# Arguments:
#   $1 - module : the module attribute path (e.g., "self.nixosModules.base")
#
# Returns:
#   0 on success
#   1 if no detailed info is available for the module
# ============================================================================
show_module_info() {
    local module="$1"
    
    # Check if the module exists in MODULE_DETAILS
    if [[ -z "${MODULE_DETAILS[$module]+x}" ]]; then
        log_warning "No detailed info available for: $module"
        return 1
    fi
    
    log_info ""
    log_info "========================================="
    log_info "  Module: $module"
    log_info "========================================="
    log_info ""
    echo "${MODULE_DETAILS[$module]}"
    log_info ""
    log_info "========================================="
    log_info ""
}

# show_current_selection <selected_array_name>
# ----------------------------------------------------------------------------
# Displays the currently selected modules.
#
# Arguments:
#   $1 - selected_ref : name of the array variable (passed by nameref)
#
# Implementation detail:
#   Uses `local -n` (bash 4.3+ nameref) to pass an array by reference,
#   allowing the function to access the caller's array without copying it.
# ============================================================================
show_current_selection() {
    local -n selected_ref=$1
    
    if [[ ${#selected_ref[@]} -eq 0 ]]; then
        log_info "Currently selected: (none)"
    else
        log_info "Currently selected:"
        for mod in "${selected_ref[@]}"; do
            log_info "  - $mod"
        done
    fi
    log_info ""
}

# ============================================================================
# Required modules tracking functions
# ============================================================================

# mark_requier_module_selected <module>
# ----------------------------------------------------------------------------
# Marks a module as selected in the __REQUIRE_MODULES tracking array.
#
# Arguments:
#   $1 - module : the module attribute path to mark as selected
#
# Side effects:
#   Updates __REQUIRE_MODULES[$module] to "true" if the module is in the
#   required modules list. Does nothing if the module is not required.
# ============================================================================
mark_requier_module_selected() {
    local module="$1"
    # Check if this module is in the required modules list
    if [[ -v __REQUIRE_MODULES[$module] ]]; then
        __REQUIRE_MODULES[$module]=true
    fi
}

# reset_requier_module_selection
# ----------------------------------------------------------------------------
# Resets all required modules to "false" in the tracking array.
# Called when the user clears their selection.
#
# Side effects:
#   Sets all values in __REQUIRE_MODULES to "false".
# ============================================================================
reset_requier_module_selection() {
    # Reset all required modules to false
    for key in "${!__REQUIRE_MODULES[@]}"; do
        __REQUIRE_MODULES[$key]=false
    done
}

# check_requier_module_selection
# ----------------------------------------------------------------------------
# Validates that all required modules have been selected.
#
# Returns:
#   0 if all required modules are selected
#   1 if any required modules are missing (prints error messages)
#
# Side effects:
#   Prints success or error messages via log_success/log_error.
# ============================================================================
check_requier_module_selection() {
    local missing_modules=()
    
    # Collect all modules that are still marked as "false" (not selected)
    for key in "${!__REQUIRE_MODULES[@]}"; do
        if [[ "${__REQUIRE_MODULES[$key]}" == "false" ]]; then
            missing_modules+=("$key")
        fi
    done
    
    # If no modules are missing, all required modules are selected
    if [[ ${#missing_modules[@]} -eq 0 ]]; then
        log_success "All required modules have been selected"
        return 0
    else
        # Print error messages for each missing required module
        log_error "The following required modules were not selected:"
        for module in "${missing_modules[@]}"; do
            log_error "  - $module"
        done
        return 1
    fi
}

# ============================================================================
# Main selection function
# ============================================================================

# select_modules
# ----------------------------------------------------------------------------
# Interactive command loop for module selection.
#
# Commands:
#   <numbers>    - select modules by number (e.g., "1 2 3")
#   i <number>   - show detailed info about module #<number>
#   l            - list all modules again
#   c            - clear current selection (also resets required module tracking)
#   d            - done, confirm selection and exit (validates required modules)
#
# Side effects:
#   - Sets global SELECTED_MODULES (space-separated list of selected modules)
#   - Updates __REQUIRE_MODULES tracking array when modules are selected
#   - Prints prompts and status messages to stdout
#
# Returns:
#   0 on successful selection (even if empty, with user confirmation)
# ============================================================================
select_modules() {
    local -a selected_modules=()
    local -a module_list=()
    
    # Build the module list once for index-to-module mapping
    for module in "${!AVAILABLE_MODULES[@]}"; do
        module_list+=("$module")
    done
    
    log_info "========================================="
    log_info "        Module Selection                 "
    log_info "========================================="
    log_info ""
    show_module_list  # just to build the list
    
    # Main command loop
    while true; do
        # Show current state
        show_current_selection selected_modules
        
        log_info "Commands:"
        log_info "  <numbers>    Select modules (e.g., '1 2 3')"
        log_info "  i <number>   Show detailed info about module"
        log_info "  l            List all modules again"
        log_info "  c            Clear selection"
        log_info "  d            Done - confirm selection"
        log_info ""
        
        read -r -p "> " input
        
        # Parse command: split input into command and argument
        # Example: "i 2" -> cmd="i", arg="2"
        # Example: "1 2 3" -> cmd="1", arg="2 3" (but we'll parse all numbers)
        local cmd="${input%% *}"
        local arg="${input#* }"
        
        case "$cmd" in
            # Info command: "i 2" or "info 2"
            i|info)
                if [[ "$arg" =~ ^[0-9]+$ && $arg -ge 1 && $arg -le ${#module_list[@]} ]]; then
                    local idx=$((arg - 1))
                    local module="${module_list[$idx]}"
        
                    show_module_info "$module"
        
                    # Check if this module is already in the selection
                    local already_selected=false
                    for sel in "${selected_modules[@]}"; do
                        if [[ "$sel" == "$module" ]]; then
                            already_selected=true
                            break
                        fi
                    done
        
                    if $already_selected; then
                        log_info "This module is already selected."
                        read -r -p "Press Enter to go back..."
                    else
                        # Offer to add the module after viewing its info
                        log_info "Would you like to add this module to your selection?"
                        read -r -p "[y] Yes, add it  [n] No, just go back: " add_choice
            
                        case "$add_choice" in
                            y|Y)
                                selected_modules+=("$module")
                                # Mark this module as selected in the required modules tracking
                                mark_requier_module_selected "$module"
                                log_info "Added: $module"
                                ;;
                            *)
                                log_info "Returning to selection menu..."
                                ;;
                        esac
                    fi
                    log_info ""
                else
                    log_warning "Invalid module number. Use: i <1-${#module_list[@]}>"
                fi
                ;;
            # List command
            l|list)
                show_module_list
                ;;
            
            # Clear command
            c|clear)
                selected_modules=()
                # Reset the required modules tracking when clearing selection
                reset_requier_module_selection
                log_info "Selection cleared."
                log_info ""
                ;;
            
            # Done command: finalize selection
            d|done)
                # Warn if no modules selected
                if [[ ${#selected_modules[@]} -eq 0 ]]; then
                    log_warning "No modules selected!"
                    read -r -p "Continue without any modules? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                
                # Validate that all required modules are selected
                if ! check_requier_module_selection; then
                    log_warning "Some required modules are missing."
                    read -r -p "Continue anyway? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                
                # Store the final selection as a space-separated string
                SELECTED_MODULES="${selected_modules[*]}"
                
                show_modules_selected
                
                return 0
                ;;
            
            # Number selection: "1 2 3"
            [0-9]*)
                local valid=true
                local new_selection=()
                
                # Parse all numbers from the input
                for num in $input; do
                    if [[ "$num" =~ ^[0-9]+$ && $num -ge 1 && $num -le ${#module_list[@]} ]]; then
                        local idx=$((num - 1))
                        local mod="${module_list[$idx]}"
                        
                        # Check for duplicates before adding
                        local already_selected=false
                        for sel in "${selected_modules[@]}"; do
                            if [[ "$sel" == "$mod" ]]; then
                                already_selected=true
                                break
                            fi
                        done
                        
                        if ! $already_selected; then
                            new_selection+=("$mod")
                            # Mark this module as selected in the required modules tracking
                            mark_requier_module_selected "$mod"
                        else
                            log_info "Already selected: $mod"
                        fi
                    else
                        log_warning "Invalid number: $num. Use 1-${#module_list[@]}."
                        valid=false
                        break
                    fi
                done
                
                # Add all valid new selections to the main array
                if $valid && [[ ${#new_selection[@]} -gt 0 ]]; then
                    selected_modules+=("${new_selection[@]}")
                    log_info "Added ${#new_selection[@]} module(s) to selection."
                    log_info ""
                fi
                ;;
            
            # Unknown command
            *)
                log_warning "Unknown command: $cmd"
                log_info "Available: <numbers>, i <n>, l, c, d"
                log_info ""
                ;;
        esac
    done
}

# ============================================================================
# Generate imports block
# ============================================================================

# generate_imports_block <modules_string>
# ----------------------------------------------------------------------------
# Converts a space-separated list of module names into a NixOS imports block.
#
# Arguments:
#   $1 - modules : space-separated list of module attribute paths
#
# Returns:
#   Prints the formatted Nix imports block to stdout.
#
# Example output:
#   imports = [
#     self.nixosModules.base
#     self.nixosModules.general
#   ];
# ============================================================================
generate_imports_block() {
    local modules="$1"
    local output="imports = [\n"
    
    for mod in $modules; do
        output+="        $mod\n"
    done
    
    output+="      ];"
    echo -e "$output"
}

# show_modules_selected
# ----------------------------------------------------------------------------
# Displays the final list of selected modules (from global SELECTED_MODULES).
# Called after the selection loop completes.
# ============================================================================
show_modules_selected() {
    # Convert space-separated string back to array
    read -ra module_array <<< "$SELECTED_MODULES"

    log_info ""
    log_info "Final selection:"
    for mod in "${module_array[@]}"; do
        log_info "  - $mod"
    done
    log_info ""
}

# module_setup
# ----------------------------------------------------------------------------
# Top-level entry point for the module selection phase.
#
# Orchestrates:
#   1. Initializes host-dependent module arrays (requires hostname to be set)
#   2. Runs the interactive selection loop (select_modules)
#   3. Generates the Nix imports block from the selection
#   4. Sets SETUP_IMPORT_MODULES for the configuration generator
#
# Prerequisites:
#   - SETUP_PREFERENCES[host.name] must be set (by host_setup.sh)
#
# Globals written:
#   - SETUP_IMPORT_MODULES  (generated Nix imports block)
#   - SELECTED_MODULES      (space-separated list of selected modules)
#
# Returns:
#   0 on success
#   1 if the user aborts or an error occurs
# ============================================================================
module_setup() {
    # Initialize module arrays that depend on the hostname
    init_host_dependent_arrays
    
    # Run the interactive selection loop
    select_modules || exit 1
    
    # Generate the Nix imports block from the selected modules
    SETUP_IMPORT_MODULES="$(generate_imports_block "$SELECTED_MODULES")"
}
