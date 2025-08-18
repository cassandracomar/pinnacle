{
  description =
    "A WIP Smithay-based Wayland compositor, inspired by AwesomeWM and configured in Lua or Rust";

  inputs = {
    # we require rustc >=1.88
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, fenix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        fenixPkgs = fenix.packages.${system};
        toolchain = fenixPkgs.stable;
        combinedToolchain = toolchain.completeToolchain;
        pinnacle-server = pkgs.callPackage ./nix/packages/pinnacle-server.nix {};
        buildPinnacleConfig = pkgs.callPackage ./nix/packages/pinnacle-config.nix {};
      in {
        formatter = pkgs.nixfmt;

        lib = {
          inherit buildPinnacleConfig;
        };

        packages = {
          inherit pinnacle-server;
        };

        devShell = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = with pkgs; [
            # rust devel tools
            combinedToolchain
            rust-analyzer
            cargo-outdated

            # wlcs
            (writeScriptBin "wlcs" ''
              #!/bin/sh
              ${wlcs}/libexec/wlcs/wlcs "$@"
            '')

            wayland

            # build time stuff
            protobuf
            lua54Packages.luarocks

            # libs
            seatd.dev
            systemdLibs.dev
            libxkbcommon
            libinput
            mesa
            xwayland
            libdisplay-info

            # winit on x11
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            xorg.libX11
          ];

          runtimeDependencies = with pkgs; [
            wayland
            mesa
            libglvnd # libEGL
          ];

          LD_LIBRARY_PATH =
            "${pkgs.wayland}/lib:${pkgs.libGL}/lib:${pkgs.libxkbcommon}/lib";
        };
      });
}
