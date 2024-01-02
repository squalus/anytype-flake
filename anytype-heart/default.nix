{ src, lib, fetchFromGitHub, buildGoModule, anytype-heart-src }:

buildGoModule {

  name = "anytype-heart-${anytype-heart-src.version}";

  inherit (anytype-heart-src) src version;

  vendorHash = "sha256-Y+uzURihYKQmow7lT9ct5/ZlyZeWOCQkts+c1IIdrf0=";

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
}
