{
  description = "Rebind - a KOReader plugin that rewrites an EPUB's embedded metadata";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages =
            with pkgs;
            [
              luajit
              gnumake
              zip
              git
              gh
              unzip
            ]
            ++ lib.optionals stdenv.hostPlatform.isDarwin [
              _7zz
              python3
            ]
            ++ lib.optionals stdenv.hostPlatform.isLinux [
              procps
              xz
            ];
          env = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            REBIND_EMULATOR_LOADER = pkgs.stdenv.cc.bintools.dynamicLinker;
            REBIND_EMULATOR_LIBS = pkgs.lib.makeLibraryPath [
              pkgs.glibc
              pkgs.stdenv.cc.cc.lib
            ];
          };
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
