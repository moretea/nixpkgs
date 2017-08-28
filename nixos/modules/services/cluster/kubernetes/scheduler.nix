{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.kubernetes;
  kubeconfig = (import ./kubeconfig.nix { inherit pkgs; inherit cfg; });
in {

  options.services.kubernetes.scheduler = {
    enable = mkOption {
      description = "Whether to enable kubernetes scheduler.";
      default = false;
      type = types.bool;
    };

    address = mkOption {
      description = "Kubernetes scheduler listening address.";
      default = "127.0.0.1";
      type = types.str;
    };

    port = mkOption {
      description = "Kubernetes scheduler listening port.";
      default = 10251;
      type = types.int;
    };

    leaderElect = mkOption {
      description = "Whether to start leader election before executing main loop";
      type = types.bool;
      default = false;
    };

    extraOpts = mkOption {
      description = "Kubernetes scheduler extra command line options.";
      default = "";
      type = types.str;
    };
  };
/*
  config = mkIf cfg.scheduler.enable {
    systemd.services.kube-scheduler = {
      description = "Kubernetes Scheduler Service";
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-apiserver.service" ];
      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = ''${cfg.package}/bin/kube-scheduler \
          --address=${cfg.scheduler.address} \
          --port=${toString cfg.scheduler.port} \
          --leader-elect=${boolToString cfg.scheduler.leaderElect} \
          --kubeconfig=${kubeconfig} \
          ${optionalString cfg.verbose "--v=6"} \
          ${optionalString cfg.verbose "--log-flush-frequency=1s"} \
          ${cfg.scheduler.extraOpts}
        '';
        WorkingDirectory = cfg.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
      };
    };
  };
  */
}

