{

  description = "Anytype";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "flake:flake-utils";
      inputs.systems.follows = "systems";
    };
    anytype-l10n = {
      url = "github:anyproto/l10n-anytype-ts";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, anytype-l10n, ... }:
  flake-utils.lib.eachDefaultSystem (system:

    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in

    with pkgs;

    let
      fix-lockfile = callPackage ./fix-lockfile {};
      remove-telemetry-deps = callPackage ./remove-telemetry-deps {};
      anytype-ts-src = callPackage ./anytype/src.nix { };
      libtantivy-go-src = callPackage ./libtantivy-go/src.nix { };
      libtantivy-go = callPackage ./libtantivy-go { inherit libtantivy-go-src; };
      anytype-heart-src = callPackage ./anytype-heart/src.nix { };
      anytype-heart = callPackage ./anytype-heart {
        inherit anytype-heart-src libtantivy-go;
      };
      anytype-protos-js = callPackage ./anytype-protos-js {
        inherit anytype-heart-src protoc-gen-js;
      };
      anytype = callPackage ./anytype {
        inherit anytype-ts-src anytype-heart anytype-protos-js fix-lockfile remove-telemetry-deps;
        anytype-l10n-src = anytype-l10n;
      };
    in

    rec {
      packages = flake-utils.lib.flattenTree {

        inherit anytype anytype-heart anytype-protos-js fix-lockfile remove-telemetry-deps protoc-gen-js libtantivy-go;

        default = anytype;

        anytype-test = nixosTest (import ./anytype/test.nix { inherit self; });

        anytype-flake-update = haskellPackages.callPackage ./update {};

      };
      checks = flake-utils.lib.flattenTree {
        inherit (packages) anytype-test anytype-flake-update;
      };
      apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/anytype";
      };

      devShells.default =
      mkShell {
        name = "package-update";
        inputsFrom = [
          packages.anytype-flake-update.env
        ];
        nativeBuildInputs = [
          haskell-language-server
          (pkgs.stdenv.mkDerivation {
              name = "hls-link";
              dontUnpack = true;
              dontBuild = true;
              installPhase = ''
                mkdir -p $out/bin
                ln -s ${haskell-language-server}/bin/haskell-language-server-wrapper $out/bin/haskell-language-server
              '';
           })
          cabal-install
          cabal2nix
          haskellPackages.fourmolu
          nix-prefetch-github
          nodejs
          prefetch-npm-deps
        ];
      };
    }
  );
}
