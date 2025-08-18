{pkgs, config, lib, ...}:
let
  cfg = config.programs.pinnacle;
in with lib.options; {
  options.programs.pinnacle =  {
    enable = mkEnableOption "pinnacle";
    package = mkPackageOption pkgs "pinnacle" {
      default = "pinnacle";
      example = "pkgs.pinnacle";
      extraDescription = "package containing the pinnacle server binary";
    };
    xdg-portals.enable = mkEnableOption "xdg-desktop-portal";
    withUWSM = mkEnableOption "uwsm";
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [cfg.package];
      services.dbus.enable = true;
      xdg.portal = mkIf cfg.xdg-portals.enable {
        enable = true;
        wlr.enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-wlr
          pkgs.xdg-desktop-portal-gtk
          pkgs.gnome-keyring
        ];
      };
    }
    (let
      pinnacle-session = pkgs.writeShellScript "pinnacle-session" ''
        #!${pkgs.runtimeShell}
        exec ${cfg.package}/bin/pinnacle --session
      '';
    in lib.mkIf (cfg.withUWSM) {
      programs.uwsm.enable = true;
      # Configure UWSM to launch Pinnacle from a display manager like SDDM
      programs.uwsm.waylandCompositors = {
        pinnacle = {
          prettyName = "Pinnacle";
          comment = "Pinnacle compositor managed by UWSM";
          binPath = "${pinnacle-session}";
        };
      };
    })
    (lib.mkIf (!cfg.withUWSM) {
      services.displayManager.sessionPackages = [cfg.package];
    })
  ]);
}
