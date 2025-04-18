{ writeShellScript, rustPlatform, cargo, libtantivy-go-src }:
rustPlatform.buildRustPackage {
  pname = "libtantivy-go";
  inherit (libtantivy-go-src) src version;
  sourceRoot = "source/rust";
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "ownedbytes-0.7.0" = "sha256-e2ffM2gRC5eww3xv9izLqukGUgduCt2u7jsqTDX5l8k=";
      "rust-stemmers-1.2.0" = "sha256-GJYFQf025U42rJEoI9eIi3xDdK6enptAr3jphuKJdiw=";
      "tantivy-jieba-0.11.0" = "sha256-BDz6+EVksgLkOj/8XXxPMVshI0X1+oLt6alDLMpnLZc=";
    };
  };
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
