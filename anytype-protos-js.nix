# pull the generated protobuf code from the binary release package
# TODO - generate these from scratch
{ lib
, stdenvNoCC
, anytype-heart-bin
}:
stdenvNoCC.mkDerivation {
  name = "anytype-protos-js-${anytype-heart-bin.version}";
  inherit (anytype-heart-bin) src version;
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
