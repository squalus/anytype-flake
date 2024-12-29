{ writeShellScript, rustPlatform, cargo, libtantivy-go-src }:
rustPlatform.buildRustPackage {
  pname = "libtantivy-go";
  inherit (libtantivy-go-src) src version;
  sourceRoot = "source/rust";
  #cargoHash = "";
  cargoDeps = rustPlatform.importCargoLock { lockFile = ./Cargo.lock; };
  patches = [ ./build.patch ];
  postPatch = ''
    cp ${./Cargo.lock} ./Cargo.lock
  '';
  passthru.updateCargoLock = writeShellScript ""
    ''
      set -euo pipefail
      set -x
      TEMPDIR=$(mktemp -d)
      pushd $TEMPDIR
      cp -r ${libtantivy-go-src.src} ./src
      chmod -R u+w src
      cd src/rust
      ${cargo}/bin/cargo generate-lockfile
      popd
      cp $TEMPDIR/src/rust/Cargo.lock libtantivy-go/Cargo.lock
    '';
}
