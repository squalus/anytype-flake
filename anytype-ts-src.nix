{ fetchFromGitHub }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./anytype-ts-src.json);
  src = fetchFromGitHub {
    owner = "anyproto";
    repo = "anytype-ts";
    inherit (lockfile) rev hash;
  };
in
{
  inherit src;
  inherit (lockfile) version;
}
