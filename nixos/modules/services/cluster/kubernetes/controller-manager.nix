{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

  kubeconfig = (import ./kubeconfig.nix { inherit pkgs; inherit cfg; });


  policyFile = pkgs.writeText "kube-policy"
    (concatStringsSep "\n" (map builtins.toJSON cfg.apiserver.authorizationPolicy));

in {
  options.services.kubernetes.controllerManager = {
    enable = mkOption {
      description = "Whether to enable kubernetes controller manager.";
      default = false;
      type = types.bool;
    };

    address = mkOption {
      description = "Kubernetes controller manager listening address.";
      default = "127.0.0.1";
      type = types.str;
    };

    port = mkOption {
      description = "Kubernetes controller manager listening port.";
      default = 10252;
      type = types.int;
    };

    leaderElect = mkOption {
      description = "Whether to start leader election before executing main loop";
      type = types.bool;
      default = false;
    };

    serviceAccountKeyFile = mkOption {
      description = ''
        Kubernetes controller manager PEM-encoded private RSA key file used to
        sign service account tokens
      '';
      default = null;
      type = types.nullOr types.path;
    };

    rootCaFile = mkOption {
      description = ''
        Kubernetes controller manager certificate authority file included in
        service account's token secret.
      '';
      default = null;
      type = types.nullOr types.path;
    };

    clusterCidr = mkOption {
      description = "Kubernetes controller manager CIDR Range for Pods in cluster";
      default = "10.10.0.0/16";
      type = types.str;
    };

    extraOpts = mkOption {
      description = "Kubernetes controller manager extra command line options.";
      default = "";
      type = types.str;
    };
  };
  config = mkIf cfg.controllerManager.enable {
   systemd.services.kube-controller-manager = {
     description = "Kubernetes Controller Manager Service";
     wantedBy = [ "kubernetes.target" ];
     after = [ "kube-apiserver.service" ];
     serviceConfig = {
       RestartSec = "30s";
       Restart = "on-failure";
       Slice = "kubernetes.slice";
       ExecStart = ''${cfg.package}/bin/kube-controller-manager \
         --address=${cfg.controllerManager.address} \
         --port=${toString cfg.controllerManager.port} \
         --kubeconfig=${kubeconfig} \
         --leader-elect=${boolToString cfg.controllerManager.leaderElect} \
         ${if (cfg.controllerManager.serviceAccountKeyFile!=null)
           then "--service-account-private-key-file=${cfg.controllerManager.serviceAccountKeyFile}"
           else "--service-account-private-key-file=/var/run/kubernetes/apiserver.key"} \
         ${optionalString (cfg.controllerManager.rootCaFile!=null)
           "--root-ca-file=${cfg.controllerManager.rootCaFile}"} \
         ${optionalString (cfg.controllerManager.clusterCidr!=null)
           "--cluster-cidr=${cfg.controllerManager.clusterCidr}"} \
         --allocate-node-cidrs=true \
         ${optionalString cfg.verbose "--v=6"} \
         ${optionalString cfg.verbose "--log-flush-frequency=1s"} \
         ${cfg.controllerManager.extraOpts}
       '';
       WorkingDirectory = cfg.dataDir;
       User = "kubernetes";
       Group = "kubernetes";
     };
   };
 };
}
