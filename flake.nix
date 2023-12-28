{

  description = "Anytype";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "flake:flake-utils";
      inputs.systems.follows = "systems";
    };
    anytype-ts = {
      url = "github:anyproto/anytype-ts?ref=v0.37.3";
      flake = false;
    };
    anytype-l10n = {
      url = "github:anyproto/l10n-anytype-ts";
      flake = false;
    };
    anytype-heart-src = {
      url = "github:anyproto/anytype-heart?ref=v0.30.4";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, anytype-ts, anytype-l10n, anytype-heart-src, ... }:
  flake-utils.lib.eachDefaultSystem (system:

    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
    in

    with pkgs;

    let
      anytype-heart-version = "0.30.4";
      anytype-ts-version = "0.37.3";
      anytype-heart = callPackage ./anytype-heart.nix {
        src = anytype-heart-src;
        version = anytype-heart-version;
      };
      anytype-protos-js = callPackage ./anytype-protos-js.nix {
        version = anytype-heart-version;
      };
      fix-lockfile = callPackage ./fix-lockfile.nix {};
    in

    rec {
      packages = flake-utils.lib.flattenTree {

        inherit anytype-heart anytype-protos-js fix-lockfile;

        anytype = callPackage ./anytype.nix {
          inherit anytype-ts-version anytype-heart anytype-protos-js fix-lockfile;
          anytype-ts-src = anytype-ts;
          anytype-l10n-src = anytype-l10n;
          electron = electron_25;
        };
        anytype-test = nixosTest (import ./test.nix { inherit self; });

      };
      checks = flake-utils.lib.flattenTree {
        inherit (packages) anytype-test;
      };

      devShells.default = mkShell {
        name = "package-update";
        nativeBuildInputs = [
          nodejs
          prefetch-npm-deps
        ];
      };
    }
  );
}
