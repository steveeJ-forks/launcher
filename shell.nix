{ sources ? import ./nix/sources.nix
, nixpkgs ? sources.nixpkgs
, holochainNixpkgsPath ? sources.holochain-nixpkgs
}:

# DEBUG LOG:
# after an initial and failing `yarn run build` this command reveals more details about what fails:
# nix-shell --run "cd src-tauri/target/release/bundle/appimage; env NO_STRIP=1 OUTPUT=holochain-launcher_0.2.0_amd64.AppImage ./linuxdeploy-x86_64.AppImage --appdir holochain-launcher.AppDir --plugin gtk --output appimage"

let
  pkgs = import nixpkgs {};

  # nodejs_16_7_0 =
  #   let
  #     buildNodejs = pkgs.callPackage "${sources.nixpkgs-master}/pkgs/development/web/nodejs/nodejs.nix" {
  #       python = pkgs.python3;
  #     };
  #   in buildNodejs {
  #     enableNpm = true;
  #     version = "16.7.0";
  #     sha256 = "0drd7zyadjrhng9k0mspz456j3pmr7kli5dd0kx8grbqsgxzv1gs";
  #     patches = [ "${sources.nixpkgs-master}/pkgs/development/web/nodejs/disable-darwin-v8-system-instrumentation.patch" ];
  #   };

  default = import ./default.nix { inherit sources nixpkgs holochainNixpkgsPath; };
  inherit (default)
    holochainNixpkgs
    ;

  myglib =
    (
      pkgs.runCommand "glibWithDev" {} ''
        mkdir $out
        cp -r ${pkgs.glib}/* $out/
        cp -r ${pkgs.glib.out}/* $out/
        find $out -type d -exec chmod +w {} +
        cp -r ${pkgs.glib.dev}/* $out/
        find $out -type d -exec chmod -w {} +

        for f in $out/lib/pkgconfig/*.pc; do
          substituteInPlace $f \
            --replace ${pkgs.glib.out} $out
        done
      ''
    )
    ;

  libs = with pkgs; [
    myglib
    cairo
    pango
    atk
    gdk-pixbuf
    libsoup
    gtk3
    webkitgtk
    gtksourceview3
    llvmPackages.libclang
    llvmPackages.libcxxClang
    libappindicator

    openssl
  ];

in pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    pkg-config
    myglib
  ];

  packages = with pkgs; [
    myglib
    clang
    squashfsTools
    pkgs.rust.packages.stable.rustc
    pkgs.rust.packages.stable.cargo
    yarn
    nodejs-16_x
  ] ++ libs;
  # TODO:
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
    (with pkgs; [
      zlib
      fuse
      harfbuzz
      libglvnd
      xlibs.libSM
      xlibs.libX11
      xlibs.libICE
      libgccjit
      libgpgerror
      fontconfig
      freetype
      xorg.libxcb
      fribidi
    ])
    ++ libs
    );

  shellHook = let
    srcTauriDirBins = "${builtins.toString ./.}/src-tauri/bins";
  in with pkgs; ''
    export LIBCLANG_PATH="${llvmPackages.libclang}/lib";
    unset SOURCE_DATE_EPOCH;

    rm -rf ${srcTauriDirBins}
    mkdir -p ${srcTauriDirBins}

    # FIXME: what about other architectures than x86_64-unknown-linux-gnu?
    cp ${holochainNixpkgs.packages.holochainAllBinariesWithDeps.main.holochain}/bin/holochain ${srcTauriDirBins}/holochain-x86_64-unknown-linux-gnu
    cp ${holochainNixpkgs.packages.holochainAllBinariesWithDeps.main.lair-keystore}/bin/lair-keystore ${srcTauriDirBins}/lair-keystore-x86_64-unknown-linux-gnu
    cp ${caddy}/bin/caddy ${srcTauriDirBins}/caddy-x86_64-unknown-linux-gnu

    # TODO: tauri tries to access these binaries in write-mode for some reason. find out why
    chmod +w \
      ${srcTauriDirBins}/holochain-x86_64-unknown-linux-gnu \
      ${srcTauriDirBins}/lair-keystore-x86_64-unknown-linux-gnu \
      ${srcTauriDirBins}/caddy-x86_64-unknown-linux-gnu
  '';
}
