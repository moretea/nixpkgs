{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.kubernetes;

  infraContainer = pkgs.dockerTools.buildImage {
    name = "pause";
    tag = "latest";
    contents = cfg.package.pause;
    config.Cmd = "/bin/pause";
  };

  manifests = pkgs.buildEnv {
    name = "kubernetes-manifests";
    paths = mapAttrsToList (name: manifest:
      pkgs.writeTextDir "${name}.json" (builtins.toJSON manifest)
    ) cfg.kubelet.manifests;
  };

  cniConfig = pkgs.buildEnv {
    name = "kubernetes-cni-config";
    paths = imap1 (i: entry:
      pkgs.writeTextDir "${toString (10+i)}-${entry.type}.conf" (builtins.toJSON entry)
    ) cfg.kubelet.cni.config;
  };

in {
  options.services.kubernetes.kubelet = {
    enable = mkOption {
      description = "Whether to enable kubernetes kubelet.";
      default = false;
      type = types.bool;
    };

    registerNode = mkOption {
      description = "Whether to auto register kubelet with API server.";
      default = true;
      type = types.bool;
    };

    registerSchedulable = mkOption {
      description = "Register the node as schedulable. No-op if register-node is false.";
      default = true;
      type = types.bool;
    };

    address = mkOption {
      description = "Kubernetes kubelet info server listening address.";
      default = "0.0.0.0";
      type = types.str;
    };

    port = mkOption {
      description = "Kubernetes kubelet info server listening port.";
      default = 10250;
      type = types.int;
    };

    tlsCertFile = mkOption {
      description = "File containing x509 Certificate for HTTPS.";
      default = null;
      type = types.nullOr types.path;
    };

    tlsKeyFile = mkOption {
      description = "File containing x509 private key matching tlsCertFile.";
      default = null;
      type = types.nullOr types.path;
    };

    healthz = {
      bind = mkOption {
        description = "Kubernetes kubelet healthz listening address.";
        default = "127.0.0.1";
        type = types.str;
      };

      port = mkOption {
        description = "Kubernetes kubelet healthz port.";
        default = 10248;
        type = types.int;
      };
    };

    hostname = mkOption {
      description = "Kubernetes kubelet hostname override";
      default = config.networking.hostName;
      type = types.str;
    };

    allowPrivileged = mkOption {
      description = "Whether to allow kubernetes containers to request privileged mode.";
      default = true;
      type = types.bool;
    };

    cadvisorPort = mkOption {
      description = "Kubernetes kubelet local cadvisor port.";
      default = 4194;
      type = types.int;
    };

    clusterDns = mkOption {
      description = "Use alternative dns.";
      default = "10.10.0.1";
      type = types.str;
    };

    clusterDomain = mkOption {
      description = "Use alternative domain.";
      default = "cluster.local";
      type = types.str;
    };

    networkPlugin = mkOption {
      description = "Network plugin to use by kubernetes";
      type = types.nullOr (types.enum ["cni" "kubenet"]);
      default = "kubenet";
    };

    cni = {
      packages = mkOption {
        description = "List of network plugin packages to install";
        type = types.listOf types.package;
        default = [];
      };

      config = mkOption {
        description = "Kubernetes CNI configuration";
        type = types.listOf types.attrs;
        default = [];
        example = literalExample ''
          [{
            "cniVersion": "0.2.0",
            "name": "mynet",
            "type": "bridge",
            "bridge": "cni0",
            "isGateway": true,
            "ipMasq": true,
            "ipam": {
                "type": "host-local",
                "subnet": "10.22.0.0/16",
                "routes": [
                    { "dst": "0.0.0.0/0" }
                ]
            }
          } {
            "cniVersion": "0.2.0",
            "type": "loopback"
          }]
        '';
      };
    };

    manifests = mkOption {
      description = "List of manifests to bootstrap with kubelet";
      type = types.attrsOf types.attrs;
      default = {};
    };

    extraOpts = mkOption {
      description = "Kubernetes kubelet extra command line options.";
      default = "";
      type = types.str;
    };
  };

  config = mkIf cfg.kubelet.enable {
      systemd.services.kubelet = {
        description = "Kubernetes Kubelet Service";
        wantedBy = [ "kubernetes.target" ];
        after = [ "network.target" "docker.service" "kube-apiserver.service" ];
        path = with pkgs; [ gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables ];
        preStart = ''
          docker load < ${infraContainer}
          rm /opt/cni/bin/* || true
          ${concatMapStringsSep "\n" (p: "ln -fs ${p.plugins}/* /opt/cni/bin") cfg.kubelet.cni.packages}
        '';
        serviceConfig = {
          Slice = "kubernetes.slice";
          ExecStart = ''${cfg.package}/bin/kubelet \
            --pod-manifest-path=${manifests} \
            --kubeconfig=${kubeconfig} \
            --require-kubeconfig \
            --address=${cfg.kubelet.address} \
            --port=${toString cfg.kubelet.port} \
            --register-node=${boolToString cfg.kubelet.registerNode} \
            --register-schedulable=${boolToString cfg.kubelet.registerSchedulable} \
            ${optionalString (cfg.kubelet.tlsCertFile != null)
              "--tls-cert-file=${cfg.kubelet.tlsCertFile}"} \
            ${optionalString (cfg.kubelet.tlsKeyFile != null)
              "--tls-private-key-file=${cfg.kubelet.tlsKeyFile}"} \
            --healthz-bind-address=${cfg.kubelet.healthz.bind} \
            --healthz-port=${toString cfg.kubelet.healthz.port} \
            --hostname-override=${cfg.kubelet.hostname} \
            --allow-privileged=${boolToString cfg.kubelet.allowPrivileged} \
            --root-dir=${cfg.dataDir} \
            --cadvisor_port=${toString cfg.kubelet.cadvisorPort} \
            ${optionalString (cfg.kubelet.clusterDns != "")
              "--cluster-dns=${cfg.kubelet.clusterDns}"} \
            ${optionalString (cfg.kubelet.clusterDomain != "")
              "--cluster-domain=${cfg.kubelet.clusterDomain}"} \
            --pod-infra-container-image=pause \
            ${optionalString (cfg.kubelet.networkPlugin != null)
              "--network-plugin=${cfg.kubelet.networkPlugin}"} \
            --cni-conf-dir=${cniConfig} \
            --reconcile-cidr \
            --hairpin-mode=hairpin-veth \
            ${optionalString cfg.verbose "--v=6 --log_flush_frequency=1s"} \
            ${cfg.kubelet.extraOpts}
          '';
          WorkingDirectory = cfg.dataDir;
        };
      };

      environment.etc = mapAttrs' (name: manifest:
        nameValuePair "kubernetes/manifests/${name}.json" {
          text = builtins.toJSON manifest;
          mode = "0755";
        }
      ) cfg.kubelet.manifests;

      # Allways include cni plugins
      services.kubernetes.kubelet.cni.packages = [pkgs.cni];
    };
}
