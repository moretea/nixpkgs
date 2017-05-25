import ./make-test.nix ({ pkgs, ... }:
let
  trivialDockerContainer =  pkgs.dockerTools.buildImage {
    name = "trivial-container";
    tag = "latest";
    contents = pkgs.nettools;
    config.Entrypoint = "/bin/hostname";
  };
in
{
  name = "hyper";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ moretea ];
  };

  machine = {...}: {
    virtualisation.hyper.enable = true;
    boot.kernelModules = [ "kvm-intel" ];
    virtualisation.qemu.options = ["-cpu qemu64,+vmx"];
    users.users = {
      noprivs = {
        isNormalUser = true;
        description = "Can't access the docker daemon";
        password = "foobar";
      };

      hasprivs = {
        isNormalUser = true;
        description = "Can access the docker daemon";
        password = "foobar";
        extraGroups = [ "hyper" ];
      };
    };
  };

  testScript = ''
    startAll;
    $machine->waitForUnit("multi-user.target");
    $machine->succeed("hyperctl load < ${trivialDockerContainer}");
    $machine->succeed("hyperctl run --rm --name='test1' trivial-container | grep test1");
    $machine->succeed("hyperctl run --rm --name='test2' trivial-container | grep test");
  '';
})
