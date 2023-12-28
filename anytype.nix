{ anytype-ts-src, anytype-ts-version, anytype-l10n-src, anytype-heart, anytype-protos-js, fix-lockfile
, lib, fetchFromGitHub, fetchurl, makeWrapper, buildNpmPackage, fetchNpmDeps
, pkg-config, libsecret, electron, libglvnd }:

let

  pname = "anytype";

  version = anytype-ts-version;

  npmDepsHash = "sha256-tJjDbit9XhwlHy6EF2YVwJAIyOxZj9vvXTS3qh+sAag=";

  npmDeps = fetchNpmDeps {
    forceGitDeps = false;
    forceEmptyCache = false;
    src = anytype-ts-src;
    srcs = null;
    sourceRoot = null;
    prePatch = "";
    patches = [];
    postPatch = ''
      # this connects to the internet and fetches missing hashes
      ${fix-lockfile}/bin/fix-lockfile.py package-lock.json package-lock.json
    '';
    name = "${pname}-npm-deps";
    hash = npmDepsHash;
  };

in

buildNpmPackage {

  name = "${pname}-${version}";

  src = anytype-ts-src;

  npmFlags = [ "--ignore-scripts" ];

  inherit npmDeps npmDepsHash;

  postPatch = ''
    cp ${npmDeps}/package-lock.json package-lock.json
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
    ELECTRON_SKIP_SENTRY=1 \
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

  passthru = {
    inherit npmDeps;
  };
}
