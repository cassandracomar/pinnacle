{
  rustPlatform,
  lib,
  pkg-config,
  xorg,
  wayland,
  lua54Packages,
  lua5_4,
  protobuf,
  seatd,
  systemdLibs,
  libxkbcommon,
  mesa,
  xwayland,
  libinput,
  libdisplay-info,
  git,
  libgbm,
  writeScriptBin,
  wlcs,
  rustc,
  cargo,
}: let
  lua = lua5_4.withPackages (ps: [lua54Packages.luarocks]);
  pinnacle = ../..;
in rustPlatform.buildRustPackage {
  pname = "pinnacle-server";
  version = "0.1.0";
  src = pinnacle;
  cargoLock = {
    lockFile = "${pinnacle}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  buildFeatures = ["wlcs"];

  buildInputs = [
    wayland

    # libs
    seatd.dev
    systemdLibs.dev
    libxkbcommon
    libinput
    mesa
    xwayland
    libdisplay-info
    libgbm
    lua5_4
    wlcs

    # winit on x11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libX11
  ];

  nativeBuildInputs = [
    pkg-config
    protobuf
    lua54Packages.luarocks
    lua5_4
    git
    wayland
    (writeScriptBin "wlcs" ''
        #!/bin/sh
        ${wlcs}/libexec/wlcs/wlcs "$@"
      '')
  ];

  # integration tests don't work inside the nix sandbox, I think because the wayland socket is inaccessible.
  cargoTestFlags = ["--lib"];
  # the below is necessary to actually execute the integration tests
  # TODO:
  #   1. figure out if it's possible to run the integration tests inside the nix sandbox
  #   2. fix the RPATH of the test binary prior to execution so LD_LIBRARY_PATH isn't necessary (it should be avoided with nix)
  # preCheck = ''
  #   export LD_LIBRARY_PATH="${wayland}/lib:${libGL}/lib:${libxkbcommon}/lib"
  # '';

  postInstall = ''
    wrapProgram $out/bin/pinnacle --prefix PATH ":" ${lib.makeBinPath [rustc cargo lua]}
  '';

  meta = {
    description = "A WIP Smithay-based Wayland compositor, inspired by AwesomeWM and configured in Lua or Rust";
    homepage = "https://pinnacle-comp.github.io/pinnacle/";
    license = lib.licenses.gpl3;
    maintainers = ["cassandracomar"];
  };
}
