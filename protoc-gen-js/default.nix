{
  bazelPackage,
  bazel_7,
  fetchFromGitHub,
  nodejs
}:

let

  version = "4.0.1";

in

bazelPackage {

  name = "protoc-gen-js";

  inherit version;

  src = fetchFromGitHub {
    owner = "protocolbuffers";
    repo = "protobuf-javascript";
    rev = "v${version}";
    hash = "sha256-PlDVaVqXg5OiCVFJZwjrkr1ds8of+WXyQbNu5aDqWFo=";
  };

  registry =  fetchFromGitHub {
    owner = "bazelbuild";
    repo = "bazel-central-registry";
    rev = "6920829d62bb2255eefe2110a9c2514301e61b97";
    hash = "sha256-GViQ0m8dV8oR8lyNUAXRZ12hGi8ESFbIem6u/QnsR1w=";
  };

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    mkdir -p $out/bin
    cp bazel-bin/generator/protoc-gen-js $out/bin
  '';

  targets = [ "generator:protoc-gen-js" ];

  bazel = bazel_7;

  env = {
    USE_BAZEL_VERSION = bazel_7.version;
  };

  bazelRepoCacheFOD = {
    outputHash = "sha256-n/gfJ+p0n9pN2DWA47AeNQEheTYHBc/Kq8o3hurD7qw=";
    outputHashAlgo = "sha256";
  };
}

