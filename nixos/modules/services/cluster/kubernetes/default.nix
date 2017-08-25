{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

  kubeconfig = (import ./kubeconfig.nix { inherit pkgs; inherit cfg; });

  policyFile = pkgs.writeText "kube-policy"
    (concatStringsSep "\n" (map builtins.toJSON cfg.apiserver.authorizationPolicy));

in {

  imports = [ ./kubelet.nix ./api-server.nix ./scheduler.nix ./controller-manager.nix];

  ###### interface

  options.services.kubernetes = {
    roles = mkOption {
      description = ''
        Kubernetes role that this machine should take.

        Master role will enable etcd, apiserver, scheduler and controller manager
        services. Node role will enable etcd, docker, kubelet and proxy services.
      '';
      default = [];
      type = types.listOf (types.enum ["master" "node"]);
    };

    package = mkOption {
      description = "Kubernetes package to use.";
      type = types.package;
      default = pkgs.kubernetes;
      defaultText = "pkgs.kubernetes";
    };

    verbose = mkOption {
      description = "Kubernetes enable verbose mode for debugging";
      default = false;
      type = types.bool;
    };

    etcd = {
      servers = mkOption {
        description = "List of etcd servers. By default etcd is started, except if this option is changed.";
        default = ["http://127.0.0.1:2379"];
        type = types.listOf types.str;
      };

      keyFile = mkOption {
        description = "Etcd key file";
        default = null;
        type = types.nullOr types.path;
      };

      certFile = mkOption {
        description = "Etcd cert file";
        default = null;
        type = types.nullOr types.path;
      };

      caFile = mkOption {
        description = "Etcd ca file";
        default = null;
        type = types.nullOr types.path;
      };
    };

    kubeconfig = {
      server = mkOption {
        description = "Kubernetes apiserver server address";
        default = "http://${cfg.apiserver.address}:${toString cfg.apiserver.port}";
        type = types.str;
      };

      caFile = mkOption {
        description = "Certificate authrority file to use to connect to kuberentes apiserver";
        type = types.nullOr types.path;
        default = null;
      };

      certFile = mkOption {
        description = "Client certificate file to use to connect to kubernetes";
        type = types.nullOr types.path;
        default = null;
      };

      keyFile = mkOption {
        description = "Client key file to use to connect to kubernetes";
        type = types.nullOr types.path;
        default = null;
      };
    };

    dataDir = mkOption {
      description = "Kubernetes root directory for managing kubelet files.";
      default = "/var/lib/kubernetes";
      type = types.path;
    };


    dns = {
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
  };

  ###### implementation

  config = mkMerge [

    (mkIf cfg.dns.enable {
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
    })

    (mkIf cfg.kubelet.enable {
      boot.kernelModules = ["br_netfilter"];
    })

    (mkIf (any (el: el == "master") cfg.roles) {
      virtualisation.docker.enable = mkDefault true;
      services.kubernetes.kubelet.enable = mkDefault true;
      services.kubernetes.kubelet.allowPrivileged = mkDefault true;
      services.kubernetes.apiserver.enable = mkDefault true;
      services.kubernetes.scheduler.enable = mkDefault true;
      services.kubernetes.controllerManager.enable = mkDefault true;
      services.etcd.enable = mkDefault (cfg.etcd.servers == ["http://127.0.0.1:2379"]);
    })

    (mkIf (any (el: el == "node") cfg.roles) {
      virtualisation.docker.enable = mkDefault true;
      virtualisation.docker.logDriver = mkDefault "json-file";
      services.kubernetes.kubelet.enable = mkDefault true;
      services.kubernetes.proxy.enable = mkDefault true;
      services.kubernetes.dns.enable = mkDefault true;
    })

    (mkIf (
        cfg.apiserver.enable ||
        cfg.scheduler.enable ||
        cfg.controllerManager.enable ||
        cfg.kubelet.enable ||
        cfg.proxy.enable ||
        cfg.dns.enable
    ) {
      systemd.targets.kubernetes = {
        description = "Kubernetes";
        wantedBy = [ "multi-user.target" ];
      };

      systemd.tmpfiles.rules = [
        "d /opt/cni/bin 0755 root root -"
        "d /var/run/kubernetes 0755 kubernetes kubernetes -"
        "d /var/lib/kubernetes 0755 kubernetes kubernetes -"
      ];

      environment.systemPackages = [ cfg.package ];
      users.extraUsers = singleton {
        name = "kubernetes";
        uid = config.ids.uids.kubernetes;
        description = "Kubernetes user";
        extraGroups = [ "docker" ];
        group = "kubernetes";
        home = cfg.dataDir;
        createHome = true;
      };
      users.extraGroups.kubernetes.gid = config.ids.gids.kubernetes;
    })
  ];
}
