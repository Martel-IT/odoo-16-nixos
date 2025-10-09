# Cloudflare Tunnel for PgAdmin
{ config, lib, pkgs, ... }:

with lib;

{
  config = let
    enabled = config.odbox.service-stack.enable &&
              config.odbox.service-stack.pgadmin-enable &&
              config.odbox.vault.cloudflare-tunnel-token-file != null;
    
    tokenFile = config.odbox.vault.cloudflare-tunnel-token-file;
  in (mkIf enabled {
    
    # Servizio systemd per cloudflared
    systemd.services.cloudflared-pgadmin = {
      description = "Cloudflare Tunnel for PgAdmin";
      after = [ "network-online.target" "pgadmin.service" ];
      wants = [ "network-online.target" ];
      requires = [ "pgadmin.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "cloudflared";
        Group = "cloudflared";
        Restart = "on-failure";
        RestartSec = "5s";
        
        ExecStart = ''
            ${pkgs.cloudflared}/bin/cloudflared --no-autoupdate tunnel run \
            --url http://localhost:5050 \
            --token-file ${tokenFile}
        '';
      };
    };

    users.users.cloudflared = {
      isSystemUser = true;
      group = "cloudflared";
      description = "Cloudflare Tunnel user";
    };
    
    users.groups.cloudflared = {};
  });
}