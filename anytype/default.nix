{ anytype-ts-src, anytype-l10n-src, anytype-heart, anytype-protos-js, fix-lockfile
, remove-telemetry-deps
, lib, fetchFromGitHub, fetchurl, makeWrapper, buildNpmPackage, fetchNpmDeps
, pkg-config, libsecret, electron_31, libglvnd, jq, moreutils, stdenvNoCC }:

let

  electron = electron_31;

  pname = "anytype";

  version = anytype-ts-src.version;

  npmDepsHash = builtins.fromJSON (builtins.readFile ./deps.json);

  srcPatchedHash = builtins.fromJSON (builtins.readFile ./src-patched.json);

  mkSrcPatched = hash: stdenvNoCC.mkDerivation {
    name = "anytype-ts-src-patched-${anytype-ts-src.version}";
    src = anytype-ts-src.src;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir $out
      cp -r . $out
      ${remove-telemetry-deps}/bin/remove-telemetry-deps.py $out
      # this connects to the internet and fetches missing hashes
      ${fix-lockfile}/bin/fix-lockfile.py $out/package-lock.json $out/package-lock.json
    '';
    outputHash = hash;
    outputHashMode = "recursive";
  };

  srcPatched = mkSrcPatched srcPatchedHash;

in

let mkPackage =
npmDepsHash: buildNpmPackage {

  name = "${pname}-${anytype-ts-src.version}";

  src = srcPatched;

  npmFlags = [ "--ignore-scripts" ];

  inherit npmDepsHash;

  patches = [
    ./0001-remove-analytics.patch
    ./0002-fix-server-path.patch
  ];

  postPatch = ''
    cp -r ${anytype-protos-js}/protobuf/* dist/lib
    mkdir -p dist/lib/json/generated
    cp -r ${anytype-protos-js}/json/* dist/lib/json/generated
    cp ${anytype-heart}/bin/grpcserver dist/anytypeHelper
    mkdir -p dist/lib/json/lang
    cp ${anytype-l10n-src}/locales/* dist/lib/json/lang
  '';

  buildInputs = [ libsecret ];

  nativeBuildInputs = [ pkg-config ];

  preBuild = ''
    npm exec electron-builder install-app-deps

    # prevent intermediate build artifacts from making it into the output and bloating the closure
    mv node_modules/keytar/build/Release/keytar.node keytar.node
    rm -rf node_modules/keytar/build
    mkdir -p node_modules/keytar/build/Release
    mv keytar.node node_modules/keytar/build/Release
  '';

  postBuild = ''
    npm exec electron-builder -- \
      --dir \
      -c.electronDist=${electron}/libexec/electron \
      -c.electronVersion=${electron.version}
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    mv dist/linux-unpacked/resources/app.asar $out/share
    mv dist/linux-unpacked/resources/app.asar.unpacked $out/share
    makeWrapper ${electron}/bin/electron $out/bin/anytype \
      --prefix LD_LIBRARY_PATH : ${libglvnd}/lib \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --set ELECTRON_FORCE_IS_PACKAGED 1 \
      --add-flags $out/share/app.asar
    cp ${./anytype.desktop} $out/share/applications/anytype.desktop
    for size in 16x16 32x32 64x64 128x128 256x256 512x512 1024x1024; do
      mkdir -p $out/share/icons/hicolor/$size/apps
      mv electron/img/icons/$size.png $out/share/icons/hicolor/$size/apps/anytype.png
    done
  '';

  meta = with lib; {
    description = "P2P note-taking tool";
    homepage = "https://anytype.io/";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
};

in

(mkPackage npmDepsHash).overrideAttrs (old: {
  passthru = {
    srcPatchedUpdate = mkSrcPatched lib.fakeHash;
    depsUpdate = mkPackage lib.fakeHash;
  };
})
