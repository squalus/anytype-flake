{ callPackage, lib, makeWrapper, nix-prefetch-github }:
(callPackage ./unwrapped.nix {}).overrideAttrs (old: {
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/anytype-flake-update \
      --prefix PATH : ${lib.getBin nix-prefetch-github}/bin
  '';
})
