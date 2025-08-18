{pkgs, config, lib, ...}:
let
  cfg = config.programs.pinnacle;
  settingsFormat = pkgs.formats.toml {};
in with lib.options; {
  options.wayland.windowManager.pinnacle = {
    enable = mkEnableOption "pinnacle";
    config = {
      package = mkPackageOption pkgs "pinnacle-config" {
        default = "pinnacle-config";
        example = "pkgs.pinnacle-config";
        extraDescription = "package containing the command/script to run as the pinnacle user configuration.";
      };

      execCmd = mkOption {
        type = lib.types.listOf (lib.types.oneOf (with lib.types; [string path]));
        default = ["${cfg.config.package}/bin/pinnacle-config"];
        example = ''["''${pkgs.pinnacle-config}/bin/pinnacle-config"]'';
        # TODO: figure out how to package and run lua configuration scripts
        description = ''
          the command to run for the pinnacle user configuration, provided via the pinnacle config toml file to the pinnacle server binary.
          this defaults to ''${pkgs.pinnacle-config}/bin/pinnacle-config -- you can provide this package via a nixpkgs overlay like:

          ```nix
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                inputs.pinnacle.overlays.default
                (final: prev: {
                  pinnacle-config = prev.pinnacle.buildRustConfig {
                    pname = "pinnacle-config";
                    version = "0.1.0";
                    src = ./.;
                  };
                })
              ];
            };
          ```

          or by setting the package option directly.

          please note that if you're running this home-manager module on a non-NixOS distribution and making use of snowcap, you need to wrap
          the call to your configuration script/executable in `nixGL` to ensure the fallback to software rendering isn't used --
          see: https://pinnacle-comp.github.io/pinnacle/getting-started/running#from-source. you should not use `nix run` here, however. instead,
          make sure the `nixGL` and `nixVulkanIntel` packages are available and invoke each:

          ```nix
            services.wayland.windowManager.pinnacle.config.execCmd = ["''${pkgs.nixGL}/bin/nixGL" "''${pkgs.nixVulkanIntel}/bin/nixVulkanIntel" "''${pkgs.pinnacle-config}/bin/pinnacle-config"];
          ```
        '';
      };
    };

    systemd = {
      enable = mkOption {
        default = true;
        example = true;
        type = lib.types.bool;
        description = ''
          create and enable the systemd user service to manage pinnacle. not enabling this option means you will need to create the user service/shutdown target yourself.
        '';
      };
    };

    extraSettings = mkOption {
      type = lib.types.attrset;

      default = {};

      example = ''
        ```nix
          programs.pinnacle.settings = {
            env = {
              "MY_ENV_VAR" = "super special env var";
            };
        };
        ```
      '';

      description = ''
        the pinnacle.toml configuration settings exposed as a nix attrset -- these are merged with the settings exposed under the `config` attr.

        see: https://pinnacle-comp.github.io/pinnacle/
      '';
    };

    mergedSettings = mkOption {
      internal = true;
      type = settingsFormat.type;
      default = {
        run = cfg.config.execCmd;
      } // cfg.extraSettings;
    };
  };

  config = let
    configFile = settingsFormat.generate "pinnacle.toml" cfg.mergedSettings;
  in with lib; mkIf cfg.enable {
    xdg.configFile."pinnacle/pinnacle.toml" = {
      source = configFile;
      # TODO: make pinnacle reload config when this file changes without needing to restart the whole graphical session
      # example: https://github.com/nix-community/home-manager/blob/2b73c2fcca690b6eca4f520179e54ae760f25d4e/modules/services/window-managers/i3-sway/sway.nix#L726
    };

    systemd.user.services.pinnacle = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "A Wayland compositor inspired by AwesomeWM";
        BindsTo = ["graphical-session.target"];
        Wants = ["graphical-session-pre.target"]
                ++ optional cfg.systemd.xdgAutostart "xdg-desktop-autostart.target";
        After = ["graphical-session-pre.target"];
        Before = ["graphical-session.target"]
                 ++ optional cfg.systemd.xdgAutostart "xdg-desktop-autostart.target";
      };
      Service = {
        Slice = ["session.slice"];
        Type = "notify";
        ExecStart = "${pkgs.pinnacle}/bin/pinnacle --session";
      };
    };

    systemd.user.targets.pinnacle-shutdown = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Shutdown running Pinnacle session";
        DefaultDependencies = false;
        StopWhenUnneeded = true;

        Conflicts = ["graphical-session.target" "graphical-session-pre.target"];
        After = ["graphical-session.target" "graphical-session-pre.target"];
      };
    };
  };
}
