{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.kubernetes;

in {
  options.services.kubernetes.api-server = {
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

  config = mkIf cfg.apiserver.enable {
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
  };
}
