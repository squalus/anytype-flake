{ fetchurl }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./anytype-heart-bin.json);
  src = fetchurl {
    inherit (lockfile) url hash;
  };
in
{
  inherit src;
  inherit (lockfile) version;
}
