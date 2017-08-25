{ pkgs, cfg }:
pkgs.writeText "kubeconfig" (builtins.toJSON {
  apiVersion = "v1";
  kind = "Config";
  clusters = [{
    name = "local";
    cluster.certificate-authority = cfg.kubeconfig.caFile;
    cluster.server = cfg.kubeconfig.server;
  }];
  users = [{
    name = "kubelet";
    user = {
      client-certificate = cfg.kubeconfig.certFile;
      client-key = cfg.kubeconfig.keyFile;
    };
  }];
  contexts = [{
    context = {
      cluster = "local";
      user = "kubelet";
    };
    current-context = "kubelet-context";
  }];
})
