{ fetchFromGitHub }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./anytype-heart-src.json);
  src = fetchFromGitHub {
    owner = "anyproto";
    repo = "anytype-heart";
    inherit (lockfile) rev hash;
  };
in
{
  inherit src;
  inherit (lockfile) version;
}
