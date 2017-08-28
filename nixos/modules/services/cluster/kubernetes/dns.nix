{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

  kubeconfig = (import ./kubeconfig.nix { inherit pkgs; inherit cfg; });


  policyFile = pkgs.writeText "kube-policy"
    (concatStringsSep "\n" (map builtins.toJSON cfg.apiserver.authorizationPolicy));

in {

  options.services.kubernetes.dns = {
    enable = mkEnableOption "kubernetes dns service.";

    port = mkOption {
      description = "Kubernetes dns listening port";
      default = 53;
      type = types.int;
    };

    domain = mkOption  {
      description = "Kuberntes dns domain under which to create names.";
      default = cfg.kubelet.clusterDomain;
      type = types.str;
    };

    extraOpts = mkOption {
      description = "Kubernetes dns extra command line options.";
      default = "";
      type = types.str;
    };
  };

/*
  config = mkIf cfg.dns.enable {
    systemd.services.kube-dns = {
      description = "Kubernetes Dns Service";
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-apiserver.service" ];
      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = ''${cfg.package}/bin/kube-dns \
          --kubecfg-file=${kubeconfig} \
          --dns-port=${toString cfg.dns.port} \
          --domain=${cfg.dns.domain} \
          ${optionalString cfg.verbose "--v=6"} \
          ${optionalString cfg.verbose "--log-flush-frequency=1s"} \
          ${cfg.dns.extraOpts}
        '';
        WorkingDirectory = cfg.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
        AmbientCapabilities = "cap_net_bind_service";
        SendSIGHUP = true;
      };
    };
  };
  */
}

