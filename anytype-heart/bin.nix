{ fetchurl }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./bin.json);
  src = fetchurl {
    inherit (lockfile) url hash;
  };
in
{
  inherit src;
  inherit (lockfile) version;
}
