# Systemd services for docker.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.virtualisation.hyper;

in

{
  ###### Interface

  options.virtualisation.hyper = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        This option enables Hyper, a daemon that manages
        isolated linux containers. Users in the "hyper" group can interact with
        the daemon (e.g. to start or stop containers) using the
        <command>hyperctl</command> command line tool.
      '';
    };

    listen = mkOption {
      type = types.str;
      default = "unix:///var/run/hyper.sock";
      description = "The unix or tcp address that hyper should listen to.";
    };

    logLevel = mkOption {
      type = types.int;
      default = 1;
      description = "Log level for the hyperd deamon";
    };
  };

  ###### Implementation

  config = mkIf cfg.enable (mkMerge [{
      environment.systemPackages = [ pkgs.hypercontainer];
      users.extraGroups.hyper.gid = config.ids.gids.hyper;
      systemd.packages = [ pkgs.hypercontainer ];

      systemd.services.hyperd = let
        configFile = pkgs.writeText "hyper.conf" ''
          Root=/var/lib/hyper
          Hypervisor=qemu-kvm
          Kernel=${pkgs.hypercontainer-guest}/var/lib/hyper/kernel
          Initrd=${pkgs.hypercontainer-guest}/var/lib/hyper/hyper-initrd.img
          StorageDriver=overlay
          BridgeIP=10.1.0.1/24
        '';
      in {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = [
            ''
              ${pkgs.hypercontainer}/bin/hyperd \
              --host=${cfg.listen} \
              --v=${toString cfg.logLevel} \
              --logtostderr \
              --config=${configFile}
            ''];
          ExecReload=[
            ""
            "${pkgs.procps}/bin/kill -s HUP $MAINPID"
          ];
        };

        # Binaries that need to be in place.
        path = with pkgs; [ xfsprogs e2fsprogs kmod qemu iptables shadow ];
      };
    }
  ]);
}
