{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

in {
  options.services.kubernetes.proxy = {
    enable = mkOption {
      description = "Whether to enable kubernetes proxy.";
      default = false;
      type = types.bool;
    };

    address = mkOption {
      description = "Kubernetes proxy listening address.";
      default = "0.0.0.0";
      type = types.str;
    };

    extraOpts = mkOption {
      description = "Kubernetes proxy extra command line options.";
      default = "";
      type = types.str;
    };
  };

  config = mkIf cfg.proxy.enable {
    systemd.services.kube-proxy = {
      description = "Kubernetes Proxy Service";
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-apiserver.service" ];
      path = [pkgs.iptables];
      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = ''${cfg.package}/bin/kube-proxy \
          --kubeconfig=${kubeconfig} \
          --bind-address=${cfg.proxy.address} \
          ${optionalString cfg.verbose "--v=6"} \
          ${optionalString cfg.verbose "--log-flush-frequency=1s"} \
          ${cfg.proxy.extraOpts}
        '';
        WorkingDirectory = cfg.dataDir;
      };
    };
  };
}
