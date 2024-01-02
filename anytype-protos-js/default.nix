{ lib
, stdenvNoCC
, anytype-heart-src
, protoc-gen-js
, protoc-gen-grpc-web
, protobuf
}:
stdenvNoCC.mkDerivation {
  name = "anytype-protos-js-${anytype-heart-src.version}";
  inherit (anytype-heart-src) src version;
  nativeBuildInputs = [ protoc-gen-grpc-web protoc-gen-js protobuf ];
  makeFlags = "protos-js";
  installPhase = ''
    mkdir -p $out/{protobuf,json}
    cp -r dist/js/pb/* $out/protobuf
    cp -r dist/js/pb/pkg/lib/* $out/protobuf
    cp pkg/lib/bundle/system*.json $out/json
    cp pkg/lib/bundle/internal*.json $out/json
  '';

   meta = with lib; {
     description = "Generated Anytype protobuf code";
     homepage = "https://github.com/anyproto/anytype-heart";
     license = licenses.unfree;
     platforms = platforms.linux;
   };
}
