{ nixpkgs ? import <nixpkgs> {} }:

let 
  pinnedSources = import ./nix/sources.nix;
  pinnedNixpkgs = import pinnedSources.nixpkgs {};

in nixpkgs.mkShell {
  buildInputs = with nixpkgs; [
    niv

    nodejs

    (nixpkgs.callPackage pinnedSources.crate2nix {})
    (nixpkgs.writeShellScriptBin "nix-regenerate-expressions" ''
      crate2nix generate --default-features -f ../src-tauri/Cargo.toml -o launcher/Cargo.nix
    '')
  ];
}
