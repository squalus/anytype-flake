{ self }:
{ pkgs, config, ... }:
{
  name = "anytype-execute-test";
  nodes.machine = {
    imports = [
      "${pkgs.path}/nixos/tests/common/x11.nix"
    ];
    config = {
      environment.systemPackages = [
        self.packages.${pkgs.system}.anytype
      ];
    };
  };

  testScript = ''
    machine.wait_for_x()
    machine.execute(
      "anytype --no-sandbox >&2 &"
    )

    machine.wait_for_window("Anytype")
  '';

}
