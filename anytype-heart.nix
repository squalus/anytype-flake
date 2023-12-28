{ src, version, lib, fetchFromGitHub, buildGoModule }:

buildGoModule {

  name = "anytype-heart-${version}";

  inherit src version;

  vendorHash = "sha256-Y+uzURihYKQmow7lT9ct5/ZlyZeWOCQkts+c1IIdrf0=";

  CGO_CFLAGS = [ "-Wno-format-security" ];

  # the C files in the dependencies get lost without this
  proxyVendor = true;

  meta = with lib; {
    description = "Shared library for Anytype clients ";
    homepage = "https://github.com/anyproto/anytype-heart";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
