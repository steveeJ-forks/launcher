{ pkgs ? import ./nix/nixpkgs.nix }:

let 
  pkgConfigDeps = with pkgs; {
    glib-sys = [[ glib ]];
    cairo-sys-rs = [[ glib cairo gobject-introspection ]];
    gobject-sys = [[ glib cairo gobject-introspection ]];
    atk-sys = [[ atk ]];
    pango-sys = [[ pango ]];
    gio-sys = [[ glib ]];
    soup-sys = [[ libsoup ]];
    gdk-pixbuf-sys = [[ gdk-pixbuf ]];
    gdk-sys = [[ gtk3 ]];
    gtk-sys = [[ gtk3 ]];
    libappindicator-sys = [
      [ glib libappindicator clang ]
      {
        LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
      }
    ];
    sysinfo = [[ glib ]];
  };

  extraDefaultCrateOverrides = pkgs.lib.attrsets.mapAttrs (name: value:
    let 
      deps = (builtins.elemAt value 0);
    in attrs: {
      nativeBuildInputs = with pkgs; [ pkg-config ] ++ deps;
      buildInputs = deps;
      propagatedBuildInputs = deps;
    } // (if builtins.length value > 1 then builtins.elemAt value 1 else {})
    )
    pkgConfigDeps
    ;

in {
  launcher = (import ./launcher/Cargo.nix { 
    inherit pkgs;
    buildRustCrateForPkgs = pkgs: pkgs.buildRustCrate.override {
      defaultCrateOverrides = pkgs.defaultCrateOverrides // extraDefaultCrateOverrides;
    };
  }).rootCrate.build;
}
