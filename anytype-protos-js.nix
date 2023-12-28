# pull the generated protobuf code from the binary release package
# TODO - generate these from scratch
{ lib
, version
, stdenvNoCC
, fetchurl
}:
stdenvNoCC.mkDerivation {
  name = "anytype-protos-js-${version}";
  inherit version;
  src = fetchurl {
    url = "https://github.com/anyproto/anytype-heart/releases/download/v${version}/js_v${version}_linux-amd64.tar.gz";
    hash = "sha256-ZgaFhCPPAKxTLylZJHP+agmU1sCI3RUN88x6Kmnh6oM=";
  };
  unpackPhase = ''
    tar xvf $src
  '';
  dontBuild = true;
  installPhase = ''
    mkdir $out
    mv protobuf json $out
  '';

   meta = with lib; {
     description = "Generated Anytype protobuf code";
     homepage = "https://github.com/anyproto/anytype-heart";
     license = licenses.unfree;
     platforms = platforms.linux;
   };
}
