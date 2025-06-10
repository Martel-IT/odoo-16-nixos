#
# Generate the NixOS systemd entry for the Nginx service.
# We start off with the Nginx SSL example config in the Odoo 14 docs
# and then bolt on recommended Nginx settings. Then we do the same
# for PgAdmin.
# See:
# - https://www.odoo.com/documentation/14.0/administration/install/deploy.html#https
# - https://www.pgadmin.org/docs/pgadmin4/8.5/server_deployment.html
#
{ autocerts, sslCertificate, sslCertificateKey, domain }:
{
    enable = true;
    # Configure basic optimisation params.
    recommendedOptimisation = true;
    # Turn on recommended proxy settings.
    # These two settings below configure all the headers required for
    # Odoo proxy mode as well as all the proxy related timeouts as in
    # in the SSL config example found in the Odoo 14 docs.
    recommendedProxySettings = true;
    proxyTimeout = "720s";
    # Ditto for TLS settings.
    # Notice this option configures all the Nginx SSL settings in the
    # Odoo example Ngnix config except for certs.
    recommendedTlsSettings = true;
    # Ditto for Gzip settings.
    # Notice the Nix config list alot of MIME types to compress. This
    # list contains all the MIME types in the Odoo config example except
    # for 'text/scss'. But 'text/scss' ain't a MIME type AFAIK. So we
    # leave that one out.
    recommendedGzipSettings = true;
    upstreams = {
      odoo.servers = {
        "127.0.0.1:8069" = {};
      };
      odoochat.servers = {
        "127.0.0.1:8072" = {};
      };
      pgadmin.servers = {
        "127.0.0.1:5050" = {};
      };
    };
    virtualHosts."${domain}" = {
      # Our Odoo stack is supposed to run on a dedicated box. So we
      # only need this one Nginx server which is why we make it the
      # the default server.
      default = true;
      # Redirect (301) plain HTTP traffic on port 80 to HTTPS on port 443.
      forceSSL = true;
      locations = {
        
        # Redirecting to "My timesheet sheet" view, skipping "Discuss" view.
        "= /" = {
          return = "302 /web#action=768&model=hr_timesheet.sheet&view_type=list&cids=1&menu_id=482";
        };
        # Forward long-polling requests to the Odoo gevent server.
        "/longpolling" = {
          proxyPass = "http://odoochat";
        };
        # Forward requests to the Odoo backend server.
        "/" = {
          proxyPass = "http://odoo";
          extraConfig = ''
            proxy_redirect off;
          '';
        };
        # Fixed PgAdmin proxy configuration for CSRF compatibility
        "/pgadmin/" = {                                       # (1)
          proxyPass = "http://pgadmin/";                      # Trailing slash aggiunto
          extraConfig = ''
            # Headers specifici per pgadmin reverse proxy
            proxy_set_header X-Script-Name /pgadmin;
            proxy_set_header X-Scheme $scheme;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            
            # Configurazioni per stabilità pgadmin
            proxy_redirect off;
            proxy_buffering off;
            proxy_set_header Connection "";
            
            # Timeout specifici per pgadmin
            proxy_connect_timeout 720s;
            proxy_send_timeout 720s;
            proxy_read_timeout 720s;
            
            # Headers per websocket se necessari
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
          '';
        };
        # Redirect da /pgadmin a /pgadmin/ per evitare problemi di trailing slash
        "= /pgadmin" = {
          return = "301 /pgadmin/";
        };
      };
    } // (if autocerts then {
        enableACME = true;                                     # (2)
    } else {
        inherit sslCertificate sslCertificateKey;
    });
}
# NOTE
# ----
# 1. Proxing PgAdmin. Our setup is conceptually the same as the one
# the PgAdmin docs recommend, but not exactly the same in terms of
# implementation. We skip `include proxy_params` since we already
# turned on `recommendedProxySettings` for the whole server. Plus,
# traffic is over the loopback interface instead of a Unix socket.
# Same same but different.
# 
# UPDATED: Added proper reverse proxy configuration for pgadmin to handle
# CSRF tokens correctly. The key changes are:
# - Added trailing slashes to both location and proxyPass
# - Added X-Script-Name header to inform pgadmin of its mount point
# - Added proper forwarding headers for HTTPS detection
# - Added redirect from /pgadmin to /pgadmin/ to avoid path issues
#
# 2. TLS certs. When using ACME we stick with the default provider,
# which is Let's Encrypt. In this case, the domain name should be
# that of the host machine. Also notice that multi-domain configs
# are supported.
# See:
# - https://nixos.org/manual/nixos/stable/#module-security-acme-nginx
# - https://nixos.wiki/wiki/Nginx
# - https://discourse.nixos.org/t/nixos-nginx-acme-ssl-certificates-for-multiple-domains
#
