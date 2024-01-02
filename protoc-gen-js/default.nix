{ stdenv, lib, fetchFromGitHub, buildBazelPackage, bazel }:
let
  version = "3.21.2";
in
buildBazelPackage {
  name = "protoc-gen-js-${version}";
  inherit bazel version;
  src = fetchFromGitHub {
    owner = "protocolbuffers";
    repo = "protobuf-javascript";
    rev = "v${version}";
    hash = "sha256-TmP6xftUVTD7yML7UEM/DB8bcsL5RFlKPyCpcboD86U=";
  };
  bazelTargets = [ "plugin_files" ];
  removeRulesCC = false;
  fetchAttrs.sha256 = "sha256-H0zTMCMFct09WdR/mzcs9FcC2OU/ZhGye7GAkx4tGa8=";
  buildAttrs = {
    installPhase = ''
      mkdir -p $out/bin
      cp bazel-bin/generator/protoc-gen-js $out/bin
    '';
  };
}
