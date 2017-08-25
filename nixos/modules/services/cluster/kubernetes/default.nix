{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

  kubeconfig = (import ./kubeconfig.nix { inherit pkgs; inherit cfg; });

  policyFile = pkgs.writeText "kube-policy"
    (concatStringsSep "\n" (map builtins.toJSON cfg.apiserver.authorizationPolicy));

in {

  imports = [ ./kubelet.nix ];

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

    apiserver = {
      enable = mkOption {
        description = "Whether to enable kubernetes apiserver.";
        default = false;
        type = types.bool;
      };

      address = mkOption {
        description = "Kubernetes apiserver listening address.";
        default = "127.0.0.1";
        type = types.str;
      };

      publicAddress = mkOption {
        description = ''
          Kubernetes apiserver public listening address used for read only and
          secure port.
        '';
        default = cfg.apiserver.address;
        type = types.str;
      };

      advertiseAddress = mkOption {
        description = ''
          Kubernetes apiserver IP address on which to advertise the apiserver
          to members of the cluster. This address must be reachable by the rest
          of the cluster.
        '';
        default = null;
        type = types.nullOr types.str;
      };

      port = mkOption {
        description = "Kubernetes apiserver listening port.";
        default = 8080;
        type = types.int;
      };

      securePort = mkOption {
        description = "Kubernetes apiserver secure port.";
        default = 443;
        type = types.int;
      };

      tlsCertFile = mkOption {
        description = "Kubernetes apiserver certificate file.";
        default = null;
        type = types.nullOr types.path;
      };

      tlsKeyFile = mkOption {
        description = "Kubernetes apiserver private key file.";
        default = null;
        type = types.nullOr types.path;
      };

      clientCaFile = mkOption {
        description = "Kubernetes apiserver CA file for client auth.";
        default = null;
        type = types.nullOr types.path;
      };

      tokenAuth = mkOption {
        description = ''
          Kubernetes apiserver token authentication file. See
          <link xlink:href="http://kubernetes.io/docs/admin/authentication.html"/>
        '';
        default = null;
        example = ''token,user,uid,"group1,group2,group3"'';
        type = types.nullOr types.lines;
      };

      authorizationMode = mkOption {
        description = ''
          Kubernetes apiserver authorization mode (AlwaysAllow/AlwaysDeny/ABAC). See
          <link xlink:href="http://kubernetes.io/v1.0/docs/admin/authorization.html"/>
        '';
        default = "AlwaysAllow";
        type = types.enum ["AlwaysAllow" "AlwaysDeny" "ABAC"];
      };

      authorizationPolicy = mkOption {
        description = ''
          Kubernetes apiserver authorization policy file. See
          <link xlink:href="http://kubernetes.io/v1.0/docs/admin/authorization.html"/>
        '';
        default = [];
        example = literalExample ''
          [
            {user = "admin";}
            {user = "scheduler"; readonly = true; kind= "pods";}
            {user = "scheduler"; kind = "bindings";}
            {user = "kubelet";  readonly = true; kind = "bindings";}
            {user = "kubelet"; kind = "events";}
            {user= "alice"; ns = "projectCaribou";}
            {user = "bob"; readonly = true; ns = "projectCaribou";}
          ]
        '';
        type = types.listOf types.attrs;
      };

      allowPrivileged = mkOption {
        description = "Whether to allow privileged containers on kubernetes.";
        default = true;
        type = types.bool;
      };

      portalNet = mkOption {
        description = "Kubernetes CIDR notation IP range from which to assign portal IPs";
        default = "10.10.10.10/24";
        type = types.str;
      };

      runtimeConfig = mkOption {
        description = ''
          Api runtime configuration. See
          <link xlink:href="http://kubernetes.io/v1.0/docs/admin/cluster-management.html"/>
        '';
        default = "";
        example = "api/all=false,api/v1=true";
        type = types.str;
      };

      admissionControl = mkOption {
        description = ''
          Kubernetes admission control plugins to use. See
          <link xlink:href="http://kubernetes.io/docs/admin/admission-controllers/"/>
        '';
        default = ["NamespaceLifecycle" "LimitRanger" "ServiceAccount" "ResourceQuota"];
        example = [
          "NamespaceLifecycle" "NamespaceExists" "LimitRanger"
          "SecurityContextDeny" "ServiceAccount" "ResourceQuota"
        ];
        type = types.listOf types.str;
      };

      serviceAccountKeyFile = mkOption {
        description = ''
          Kubernetes apiserver PEM-encoded x509 RSA private or public key file,
          used to verify ServiceAccount tokens. By default tls private key file
          is used.
        '';
        default = null;
        type = types.nullOr types.path;
      };

      kubeletClientCaFile = mkOption {
        description = "Path to a cert file for connecting to kubelet";
        default = null;
        type = types.nullOr types.path;
      };

      kubeletClientCertFile = mkOption {
        description = "Client certificate to use for connections to kubelet";
        default = null;
        type = types.nullOr types.path;
      };

      kubeletClientKeyFile = mkOption {
        description = "Key to use for connections to kubelet";
        default = null;
        type = types.nullOr types.path;
      };

      kubeletHttps = mkOption {
        description = "Whether to use https for connections to kubelet";
        default = true;
        type = types.bool;
      };

      extraOpts = mkOption {
        description = "Kubernetes apiserver extra command line options.";
        default = "";
        type = types.str;
      };
    };

    scheduler = {
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

    controllerManager = {
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


    proxy = {
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
    (mkIf cfg.apiserver.enable {
      systemd.services.kube-apiserver = {
        description = "Kubernetes Kubelet Service";
        wantedBy = [ "kubernetes.target" ];
        after = [ "network.target" "docker.service" ];
        serviceConfig = {
          Slice = "kubernetes.slice";
          ExecStart = ''${cfg.package}/bin/kube-apiserver \
            --etcd-servers=${concatStringsSep "," cfg.etcd.servers} \
            ${optionalString (cfg.etcd.caFile != null)
              "--etcd-cafile=${cfg.etcd.caFile}"} \
            ${optionalString (cfg.etcd.certFile != null)
              "--etcd-certfile=${cfg.etcd.certFile}"} \
            ${optionalString (cfg.etcd.keyFile != null)
              "--etcd-keyfile=${cfg.etcd.keyFile}"} \
            --insecure-port=${toString cfg.apiserver.port} \
            --bind-address=0.0.0.0 \
            ${optionalString (cfg.apiserver.advertiseAddress != null)
              "--advertise-address=${cfg.apiserver.advertiseAddress}"} \
            --allow-privileged=${boolToString cfg.apiserver.allowPrivileged}\
            ${optionalString (cfg.apiserver.tlsCertFile != null)
              "--tls-cert-file=${cfg.apiserver.tlsCertFile}"} \
            ${optionalString (cfg.apiserver.tlsKeyFile != null)
              "--tls-private-key-file=${cfg.apiserver.tlsKeyFile}"} \
            ${optionalString (cfg.apiserver.tokenAuth != null)
              "--token-auth-file=${cfg.apiserver.tokenAuth}"} \
            --kubelet-https=${boolToString cfg.apiserver.kubeletHttps} \
            ${optionalString (cfg.apiserver.kubeletClientCaFile != null)
              "--kubelet-certificate-authority=${cfg.apiserver.kubeletClientCaFile}"} \
            ${optionalString (cfg.apiserver.kubeletClientCertFile != null)
              "--kubelet-client-certificate=${cfg.apiserver.kubeletClientCertFile}"} \
            ${optionalString (cfg.apiserver.kubeletClientKeyFile != null)
              "--kubelet-client-key=${cfg.apiserver.kubeletClientKeyFile}"} \
            ${optionalString (cfg.apiserver.clientCaFile != null)
              "--client-ca-file=${cfg.apiserver.clientCaFile}"} \
            --authorization-mode=${cfg.apiserver.authorizationMode} \
            ${optionalString (cfg.apiserver.authorizationMode == "ABAC")
              "--authorization-policy-file=${policyFile}"} \
            --secure-port=${toString cfg.apiserver.securePort} \
            --service-cluster-ip-range=${cfg.apiserver.portalNet} \
            ${optionalString (cfg.apiserver.runtimeConfig != "")
              "--runtime-config=${cfg.apiserver.runtimeConfig}"} \
            --admission_control=${concatStringsSep "," cfg.apiserver.admissionControl} \
            ${optionalString (cfg.apiserver.serviceAccountKeyFile!=null)
              "--service-account-key-file=${cfg.apiserver.serviceAccountKeyFile}"} \
            ${optionalString cfg.verbose "--v=6"} \
            ${optionalString cfg.verbose "--log-flush-frequency=1s"} \
            ${cfg.apiserver.extraOpts}
          '';
          WorkingDirectory = cfg.dataDir;
          User = "kubernetes";
          Group = "kubernetes";
          AmbientCapabilities = "cap_net_bind_service";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    (mkIf cfg.scheduler.enable {
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
    })

    (mkIf cfg.controllerManager.enable {
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
    })

    (mkIf cfg.proxy.enable {
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
    })

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
