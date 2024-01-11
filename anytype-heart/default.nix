{ src, lib, fetchFromGitHub, buildGoModule, anytype-heart-src }:

let

  vendorHash = builtins.fromJSON (builtins.readFile ./vendorHash.json);

  pkg = vendorHash: buildGoModule {

    name = "anytype-heart-${anytype-heart-src.version}";

    inherit vendorHash;

    inherit (anytype-heart-src) src version;

    CGO_CFLAGS = [ "-Wno-format-security" ];

    # the C files in the dependencies get lost without this
    proxyVendor = true;

    doCheck = false;

    patches = [ ./0001-remove-amplitude-analytics.patch ];

    meta = with lib; {
      description = "Shared library for Anytype clients ";
      homepage = "https://github.com/anyproto/anytype-heart";
      license = licenses.unfree;
      platforms = platforms.linux;
    };
  };

in

(pkg vendorHash).overrideAttrs (old: {
  passthru.vendorHashUpdate = (pkg lib.fakeHash).goModules;
})
