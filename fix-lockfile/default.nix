{ lib, makeWrapper, stdenvNoCC, python3, cacert }:

stdenvNoCC.mkDerivation {
    name = "fix-lockfile";
    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ makeWrapper python3 ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${./fix-lockfile.py} $out/bin/fix-lockfile.py
      patchShebangs $out/bin/fix-lockfile.py
      wrapProgram $out/bin/fix-lockfile.py \
        --set NIX_SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
    '';
}
