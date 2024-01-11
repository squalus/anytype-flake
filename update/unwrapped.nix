{ mkDerivation, aeson, base, base64, bytestring, casing, conduit
, conduit-extra, containers, cryptohash-md5, cryptohash-sha256
, directory, filepath, github, http-conduit, http-types, lib
, optparse-applicative, optparse-text, text, typed-process, vector
}:
mkDerivation {
  pname = "anytype-flake-update";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base base64 bytestring casing conduit conduit-extra
    containers cryptohash-md5 cryptohash-sha256 directory filepath
    github http-conduit http-types optparse-applicative optparse-text
    text typed-process vector
  ];
  license = lib.licenses.bsd0;
  mainProgram = "anytype-flake-update";
}
