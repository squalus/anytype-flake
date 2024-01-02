{ fetchFromGitHub }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./src.json);
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
