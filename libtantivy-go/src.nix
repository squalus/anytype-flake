{ fetchFromGitHub }:
let
  lockfile = builtins.fromJSON (builtins.readFile ./src.json);
  src = fetchFromGitHub {
    owner = "anyproto";
    repo = "tantivy-go";
    inherit (lockfile) rev hash;
  };
in
{
  inherit src;
  inherit (lockfile) version;
}
