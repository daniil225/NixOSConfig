#!/usr/bin/env bash
# ==============================================================================
# configuration_generator.sh
# ------------------------------------------------------------------------------
# Purpose:
#   Generates NixOS host configuration files based on previously collected
#   user preferences and selected modules:
#     - configuration.nix        (main host configuration)
#     - hardware-configuration.nix (hardware-specific settings)
#     - disko.nix                (declarative disk partitioning)
#
# Workflow:
#   1. Prints a summary of collected host preferences and selected modules.
#   2. Generates configuration.nix template in the target host directory.
#   3. Formats the file with nixfmt for consistent style.
#   4. Enters an interactive review/edit loop for user inspection.
#   5. Repeats steps 2-4 for hardware-configuration.nix and disko.nix.
#
# Dependencies:
#   - utils.sh        (logging helpers: log_info, log_warning, log_success)
#   - guard_run       (idempotency guard, prevents double-sourcing)
#   - nixfmt          (Nix code formatter, must be in PATH)
#   - Global arrays:  SETUP_PREFERENCES, SETUP_IMPORT_MODULES,
#                     SETUP_HOST_PREFERENCES, SETUP_HW_HOST_CONFIG,
#                     SETUP_USER_HOST_DIR
# ==============================================================================

# ------------------------------------------------------------------------------
# Bootstrap: load shared utilities and activate the run guard.
# `guard_run` ensures the script is not executed/sourced twice in the same
# shell session, which is important because it mutates global state.
# ------------------------------------------------------------------------------
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/utils.sh"
guard_run "${BASH_SOURCE[0]}" "${0}"


# ==============================================================================
# Configuration generator
# ==============================================================================

# ------------------------------------------------------------------------------
# Default editor selection with a fallback chain.
# Honors the user's $EDITOR environment variable if set; otherwise falls back
# to `nano`, and finally to `vi` if neither is available on the system.
# ------------------------------------------------------------------------------
: "${EDITOR:=nano}"
command -v "$EDITOR" >/dev/null 2>&1 || EDITOR="vi"


# ==============================================================================
# Summary
# ==============================================================================

# ------------------------------------------------------------------------------
# show_host_configuration_summary()
#
# Description:
#   Prints a human-readable summary of everything collected so far:
#     - General setup preferences (host name, user, disk layout, etc.)
#     - The list of NixOS modules the user opted into
#
# Globals read:
#   SETUP_PREFERENCES, SETUP_IMPORT_MODULES, SETUP_HOST_PREFERENCES
#   (indirectly, via show_setuped_preferences / show_modules_selected)
# ------------------------------------------------------------------------------
show_host_configuration_summary() {
    log_info "========================================="
    log_info "       Host Configuration Summary        "
    log_info "========================================="
    show_setuped_preferences
    log_info "========================================="
    log_info "       Host Configuration Summary        "
    log_info "========================================="
    show_disk_setuped_preferences
    log_info "========================================="
    log_info "========================================="
    log_info "       Modules Configuration Summary     "
    log_info "========================================="
    show_modules_selected
    log_info "========================================="
}


# ==============================================================================
# Helper function for writing Nix configuration files
# ==============================================================================

# ------------------------------------------------------------------------------
# write_nix_config_file()
#
# Description:
#   Writes a Nix configuration file with common pre/post processing:
#     - Creates target directory if it doesn't exist
#     - Checks for existing file and prompts for overwrite confirmation
#     - Writes the content to the file
#     - Sets the specified global variable to the file path
#
# Arguments:
#   $1 - target_dir      : directory where the file will be written
#   $2 - filename        : name of the file (e.g., "configuration.nix")
#   $3 - content         : content to write to the file
#   $4 - global_var_name : name of the global variable to set with the file path
#
# Returns:
#   0 on success
#   1 if the user declined to overwrite an existing file
# ------------------------------------------------------------------------------
write_nix_config_file() {
    local target_dir="$1"
    local filename="$2"
    local content="$3"
    local global_var_name="$4"
    
    local target_file="${target_dir}/${filename}"
    
    # Ensure the destination directory exists before writing.
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_info "Created directory: $target_dir"
    fi
    
    # Guard against accidental overwrites — always ask the user first.
    if [[ -f "$target_file" ]]; then
        log_warning "File already exists: $target_file"
        read -r -p "Overwrite? [y/N]: " answer
        case "$answer" in
            y|Y)
                log_info "Overwriting existing file."
                ;;
            *)
                log_info "Skipped. Existing file left unchanged."
                return 1  # signal to caller: file was not generated
                ;;
        esac
    fi
    
    # Write the content to the file
    echo "$content" > "$target_file"
    
    log_info "Generated config: $target_file"
    
    # Expose the generated path to the caller via a global variable
    declare -g "$global_var_name=$target_file"
}


# ==============================================================================
# Configuration generators
# ==============================================================================

# ------------------------------------------------------------------------------
# generate_host_config()
#
# Description:
#   Generates the base configuration.nix template for the host being set up.
#
# Arguments:
#   $1 - target_dir : directory where configuration.nix will be written
#                     (created if it does not exist)
#
# Side effects:
#   - Creates $target_dir if missing.
#   - Prompts the user for confirmation before overwriting an existing file.
#   - Writes the generated Nix template to $target_dir/configuration.nix.
#   - Sets the global SETUP_NIXOS_CONF_FILE to the path of the written file.
#
# Returns:
#   0 on success
#   1 if the user declined to overwrite an existing file (file left untouched)
# ------------------------------------------------------------------------------
generate_host_config() {
    local target_dir="$1"
    
    # --------------------------------------------------------------------------
    # Write the NixOS configuration template.
    #
    # The template exposes:
    #   - flake.nixosConfigurations.<host> : the top-level nixosSystem entry
    #   - flake.nixosModules.host-<host>   : the per-host module that pulls in
    #                                        user-selected imports and prefs
    #
    # Variables expanded inside the heredoc (from the caller's environment):
    #   SETUP_PREFERENCES[host.name]  - hostname, used to name the flake attrs
    #   SETUP_IMPORT_MODULES          - list of `imports = [ ... ];` lines
    #   SETUP_HOST_PREFERENCES        - host-specific preference overrides
    # --------------------------------------------------------------------------
    local content
    content=$(cat <<EOF
{
  inputs,
  self,
  ...
}:
{
  # Entry point for host:
  flake.nixosConfigurations.${SETUP_PREFERENCES[host.name]} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.host-${SETUP_PREFERENCES[host.name]}
    ];
  };

  flake.nixosModules.host-${SETUP_PREFERENCES[host.name]} =
    { pkgs, config, ... }:
    {

      ${SETUP_IMPORT_MODULES}

      ${SETUP_HOST_PREFERENCES}

      # Bootloader (from system config)
      boot = {
        loader = {
          grub.enable = true;
          grub.efiSupport = true;
          grub.efiInstallAsRemovable = true;
          grub.useOSProber = true;
          grub.devices = ["nodev"];
          #systemd-boot.enable = true;
          #efi.canTouchEfiVariables = true;
        };
      };

      networking = {
        hostName = config.preferences.network.host.name;
        networkmanager.enable = true;
      };

      services = {
        # X11 windowing system.
        xserver = {
          enable = true;
          # Enable the GNOME Desktop Environment.
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;
          # Configure keymap in X11
          xkb = {
            layout = "us,ru";
            variant = "";
            options = "grp:win_space_toggle";
          };
        };

        # Enable CUPS to print documents.
        printing.enable = true;

        # Enable sound with pipewire.
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };

      security = {
        rtkit.enable = true;
      };

      # Needs to be decomposed
      environment.systemPackages = with pkgs; [
        wget
        vscode
        vim
        nano
        git
        jq
        shfmt
        gptfdisk # disk formater
        parted # partirion table update
        bc
      ];

      system.stateVersion = "25.11";
    };
}
EOF
)
    
    write_nix_config_file "$target_dir" "configuration.nix" "$content" "SETUP_NIXOS_CONF_FILE"
}

# ------------------------------------------------------------------------------
# generate_hw_host_config()
#
# Description:
#   Generates the hardware-configuration.nix template for the host.
#   This file contains hardware-specific settings (disk layout, filesystems,
#   kernel modules, etc.) that are typically auto-detected by nixos-generate-config.
#
# Arguments:
#   $1 - target_dir : directory where hardware-configuration.nix will be written
#                     (created if it does not exist)
#
# Side effects:
#   - Creates $target_dir if missing.
#   - Prompts the user for confirmation before overwriting an existing file.
#   - Writes the generated Nix template to $target_dir/hardware-configuration.nix.
#   - Sets the global SETUP_NIXOS_HW_CONF_FILE to the path of the written file.
#
# Globals read:
#   SETUP_PREFERENCES[host.name]  - hostname, used to name the flake module
#   SETUP_HW_HOST_CONFIG          - hardware-specific Nix configuration block
#                                   (populated by hw_conf_gen.sh or disk_setup.sh)
#
# Returns:
#   0 on success
#   1 if the user declined to overwrite an existing file (file left untouched)
# ------------------------------------------------------------------------------
generate_hw_host_config() {
    local target_dir="$1"
    
    # --------------------------------------------------------------------------
    # Write the hardware configuration template.
    #
    # The template defines a flake module that can be imported into the host
    # configuration. The actual hardware settings are injected via the
    # SETUP_HW_HOST_CONFIG variable, which should contain Nix attribute sets
    # like fileSystems, boot.initrd, networking.interfaces, etc.
    # --------------------------------------------------------------------------
    local content
    content=$(cat <<EOF
{
  flake.nixosModules.host-${SETUP_PREFERENCES[host.name]} =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      ${SETUP_HW_HOST_CONFIG}
    };
  }
EOF
)
    
    write_nix_config_file "$target_dir" "hardware-configuration.nix" "$content" "SETUP_NIXOS_HW_CONF_FILE"
}

# ------------------------------------------------------------------------------
# generate_disko_config()
#
# Description:
#   Generates the disko.nix template for the host.
#   This file contains declarative disk partitioning configuration for disko.
#
# Arguments:
#   $1 - target_dir : directory where disko.nix will be written
#                     (created if it does not exist)
#
# Side effects:
#   - Creates $target_dir if missing.
#   - Prompts the user for confirmation before overwriting an existing file.
#   - Writes the generated Nix template to $target_dir/disko.nix.
#   - Sets the global SETUP_NIXOS_DISKO_CONF_FILE to the path of the written file.
#
# Returns:
#   0 on success
#   1 if the user declined to overwrite an existing file (file left untouched)
# ------------------------------------------------------------------------------
generate_disko_config() {
    local target_dir="$1"
    local tmp_disko_conf="/tmp"
    
    local flake_content
    local disko_content 
    local content

    content=$(cat <<EOF
      disko.devices = {
        disk = {
          main = {
            type = "disk";
            device = "/dev/disk/by-id/${SETUP_DISK_PREFERENCES[disk_by_id]}";
            content = {
              type = "gpt";
              partitions = {
                ${SETUP_DISK_CONF}
              };
            };
          };
        };
      };
EOF
)
  disko_content="{
      ${content}
    }"


  flake_content=$(cat <<EOF
  {
    flake.diskoConfigurations.host-${SETUP_PREFERENCES[host.name]} = {
      ${content}
    };
  }
EOF
)
    
  write_nix_config_file "$target_dir" "disko.nix" "$flake_content" "SETUP_NIXOS_DISKO_CONF_FILE"
  write_nix_config_file "$tmp_disko_conf" "disko.nix" "$disko_content" "SETUP_TMP_DISKO_CONF_FILE"
}


# ==============================================================================
# File display and editing helpers
# ==============================================================================

# ------------------------------------------------------------------------------
# show_file()
#
# Description:
#   Displays the contents of a file using the best available pager.
#
# Priority:
#   less > more > cat (raw output, no paging).
#
# Arguments:
#   $1 - file : path to the file to display
# ------------------------------------------------------------------------------
show_file() {
    local file="$1"
    if command -v less >/dev/null 2>&1; then
        less "$file"
    elif command -v more >/dev/null 2>&1; then
        more "$file"
    else
        cat "$file"
    fi
}

# ------------------------------------------------------------------------------
# edit_file()
#
# Description:
#   Opens the given file in the user's preferred editor ($EDITOR).
#
# Arguments:
#   $1 - file : path to the file to edit
# ------------------------------------------------------------------------------
edit_file() {
    local file="$1"
    log_info "Opening $file in $EDITOR ..."
    "$EDITOR" "$file"
}


# ==============================================================================
# Interactive review loop
# ==============================================================================

# ------------------------------------------------------------------------------
# manual_check_generated_file()
#
# Description:
#   Interactive review loop for a generated configuration file.
#   Allows the user to inspect, edit, view, or abort the file before proceeding.
#
# Arguments:
#   $1 - config_file : path to the generated file to review
#
# Actions:
#   [y] Accept the file and continue
#   [n] Open in $EDITOR, then re-display the file
#   [v] View the file through a pager (less/more/cat)
#   [a] Abort — removes the generated file and returns failure
#
# Side effects:
#   - May delete the file if the user chooses to abort.
#   - May modify the file if the user edits it.
#
# Returns:
#   0 if the user accepted the file
#   1 if the user aborted (file is removed)
# ------------------------------------------------------------------------------
manual_check_generated_file() {
    local config_file="${1}"
    while true; do
        log_info ""
        log_info "Generated configuration is ready at: $config_file"
        log_info ""
        log_info "Actions:"
        log_info "  [y] Looks good, continue"
        log_info "  [n] Open in editor to fix"
        log_info "  [v] View the file (pager)"
        log_info "  [a] Abort and start over"
        read -r -p "Your choice [y/n/v/a]: " action

        case "$action" in
            y|Y)
                log_info "Configuration accepted."
                break
                ;;
            n|N)
                edit_file "$config_file"
                log_info "Re-open the file to review your changes."
                show_file "$config_file"
                ;;
            v|V)
                show_file "$config_file"
                ;;
            a|A)
                log_warning "Aborted by user. Generated file removed."
                rm -f "$config_file"
                return 1
                ;;
            *)
                log_warning "Invalid choice. Please enter y, n, v, or a."
                ;;
        esac
    done
}


# ==============================================================================
# Main entry point
# ==============================================================================

# ------------------------------------------------------------------------------
# conf_gen()
#
# Description:
#   Top-level entry point of the configuration generator.
#   Orchestrates the full flow for all configuration files.
#
# Workflow:
#   1. Prints the collected preferences / modules summary.
#   2. Generates configuration.nix via generate_host_config.
#   3. Formats the file with nixfmt for consistent Nix style.
#   4. Enters an interactive review loop via manual_check_generated_file.
#   5. Repeats steps 2-4 for hardware-configuration.nix and disko.nix.
#
# Globals used:
#   SETUP_USER_HOST_DIR        - destination directory for the host config
#   SETUP_NIXOS_CONF_FILE      - set by generate_host_config, consumed here
#   SETUP_NIXOS_HW_CONF_FILE   - set by generate_hw_host_config, consumed here
#   SETUP_NIXOS_DISKO_CONF_FILE - set by generate_disko_config, consumed here
#
# Dependencies:
#   - nixfmt : must be available in PATH for automatic formatting
#
# Returns:
#   0 if the user accepted all configurations
#   1 if the user aborted at any step
# ------------------------------------------------------------------------------
conf_gen() {
    log_info "========================================="
    log_info "         Configuration Generator         "
    log_info "========================================="

    # 1. Show collected parameters summary
    show_host_configuration_summary

    # 2. Generate the main config file (configuration.nix)
    generate_host_config "$SETUP_USER_HOST_DIR"
    # Format with nixfmt for consistent style
    nixfmt "${SETUP_NIXOS_CONF_FILE}"
    # Interactive review loop
    manual_check_generated_file "${SETUP_NIXOS_CONF_FILE}"

    # 3. Generate the hardware config file (hardware-configuration.nix)
    generate_hw_host_config "$SETUP_USER_HOST_DIR"
    # Format with nixfmt for consistent style
    nixfmt "${SETUP_NIXOS_HW_CONF_FILE}"
    # Interactive review loop
    manual_check_generated_file "${SETUP_NIXOS_HW_CONF_FILE}"

    # 4. Generate disk partition config (disko.nix)
    #    Defines the boot, root, swap layout
    generate_disko_config "$SETUP_USER_HOST_DIR"
    # Format with nixfmt for consistent style
    nixfmt "${SETUP_NIXOS_DISKO_CONF_FILE}"
    nixfmt "${SETUP_TMP_DISKO_CONF_FILE}"
    # Interactive review loop
    manual_check_generated_file "${SETUP_NIXOS_DISKO_CONF_FILE}"
    manual_check_generated_file "${SETUP_TMP_DISKO_CONF_FILE}"

    log_success "========================================="
    log_success "   Configuration generation completed    "
    log_success "========================================="
}
