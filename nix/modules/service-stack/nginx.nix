# nix/pkgs/service-stack/nginx.nix
{ autocerts, sslCertificate, sslCertificateKey, domain }:
{
    enable = true;
    
    # Configure basic optimisation params.
    recommendedOptimisation = true;
    
    # Turn on recommended proxy settings.
    recommendedProxySettings = true;
    proxyTimeout = "720s";
    
    # Ditto for TLS settings.
    recommendedTlsSettings = true;
    
    # Ditto for Gzip settings.
    recommendedGzipSettings = true;
    
    upstreams = {
      odoo.servers = {
        "127.0.0.1:8069" = {};
      };
      odoochat.servers = {
        "127.0.0.1:8072" = {};
      };
    };
    
    virtualHosts."${domain}" = {
      # Our Odoo stack is supposed to run on a dedicated box.
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
      };
    } // (if autocerts then {
        enableACME = true;
    } else {
        inherit sslCertificate sslCertificateKey;
    });
}