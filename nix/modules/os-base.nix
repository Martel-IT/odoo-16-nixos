#
# A simple system base with CLI tools and Emacs.
# This module installs:
#
# * Emacs (built w/o X11 deps)
# * Bash completion and a given set of CLI tools
# * Nix Flakes extension
#
# and then makes:
#
# * Emacs the default editor system-wide (`EDITOR` environment variable)
#
# Finally, this module configures users by
# - only allowing to change users and groups through NixOS config;
# - letting wheel users run `sudo` without a password.
#
# Because wheel users don't have to enter a password to `sudo`, you
# could have wheel users without passwords if you wanted to. In this
# setup, a wheel user would be configured with an SSH key to log in
# but no system password. Obviously, this kind of arrangement works
# as long as those users only ever log in through SSH.
#
# Finally notice the `odbox.login` module takes care of setting up
# access for the admin and root users.
#
{ config, lib, pkgs, ... }:

with lib;
with types;

{

  options = {
    odbox.base.enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable it to install this system base.
      '';
    };
    odbox.base.cli-tools = mkOption {
      type = listOf package;
      default = [];
      description = ''
        CLI tools to install system-wide.
      '';
    };
  };

  config = let
    enabled = config.odbox.base.enable;
    tools = config.odbox.base.cli-tools;
  in (mkIf enabled
  {
    # CVE-2025-32463 FIX - Override sudo to patched version
    nixpkgs.overlays = [
      (final: prev: {
        sudo = prev.sudo.overrideAttrs (oldAttrs: rec {
          version = "1.9.17p1";
          src = prev.fetchurl {
            url = "https://www.sudo.ws/dist/sudo-${version}.tar.gz";
            sha256 = "0cjx8lkwlqz03psnaia07rz9mpyn5ilpixvqi9rrf8872ykpwq7z";
          };
        });
      })
    ];

    # Enable Flakes.
    nix = {
      package = pkgs.nixFlakes;
      settings.experimental-features = [ "nix-command" "flakes" ];
    };

    # Install Emacs and make it the default editor system-wide.
    # Also install the given CLI tools and enable Bash completion.
    environment.systemPackages = [ pkgs.emacs-nox pkgs.sassc ] ++ tools;
    environment.variables = {
      EDITOR = "emacs";    # NOTE (1)
    };
    programs.bash.enableCompletion = true;

    # Only allow to change users and groups through NixOS config.
    users.mutableUsers = false;

    # Let wheel users run `sudo` without a password.
    security.sudo.wheelNeedsPassword = false;
  });

}
# NOTE
# ----
# 1. Command Paths. Should we use absolute paths to the Nix derivations?
# Seems kinda pointless b/c programs added to systemPackages will be in
# the PATH anyway...
#