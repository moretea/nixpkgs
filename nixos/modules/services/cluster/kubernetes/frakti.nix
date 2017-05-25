# TODO:
# Check extra opties
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.frakti;
in {

  ##### Interface
  options.services.frakti = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the frakti service.";
    };

    listen = mkOption {
      type = types.str;
      default = "/var/run/frakti.sock";
      description = "Frakti listening addresses.";
    };

    hyperEndpoint = mkOption {
      type = types.str;
      default = config.services.hyper.gRPCHost;
      description = "Hyper gRPC endpoint.";
    };

    logLevel = mkOption {
      type = types.int;
      default = 1;
      description = "Log level for the deamon";
    };
  };

  ##### Implementation
  config = mkIf cfg.enable {
    systemd.services.frakti = {
      description = "Frakti Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "hyperd.target" ];
      requires = [ "hyperd.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.kubernetes-frakti}/bin/frakti";
        Group = "hyperd";
      };
    };

    services.hyperd.enable = mkDefault true;
  };
}
