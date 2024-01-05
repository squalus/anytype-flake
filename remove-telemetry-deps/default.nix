{ lib, stdenvNoCC, python3 }:

stdenvNoCC.mkDerivation {
    name = "remove-telemetry-deps";
    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ python3 ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${./remove-telemetry-deps.py} $out/bin/remove-telemetry-deps.py
      patchShebangs $out/bin/remove-telemetry-deps.py
    '';
}
