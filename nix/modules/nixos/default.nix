{pkgs, config, lib, ...}:
let
  cfg = config.programs.pinnacle;
in with lib.options; {
  options.programs.pinnacle =  {
    enable = mkEnableOption "pinnacle";
    xdg-portals.enable = mkEnableOption "xdg-desktop-portal";
  };

  config = mkIf cfg.enable {
    services.xserver.displayManager.sessionPackages = [pkgs.pinnacle-server];
    environment.systemPackages = [pkgs.pinnacle-server];

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
  };
}
