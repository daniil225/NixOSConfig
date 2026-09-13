{ ... }:
{
  flake.nixosModules.docker = { config, ... }: {
    virtualisation.docker.enable = true;
    users.users.${config.preferences.user.name}.extraGroups = [ "docker" ];
    virtualisation.oci-containers.backend = "docker";

    systemd.tmpfiles.rules = [
      "d /var/lib/pgadmin-data 0755 5050 5050 - -"
      "d /var/lib/postgres-data 0700 999 999 - -"
    ];

    virtualisation.docker.networks = {
      db-course-network = {
        drive = "bridge";
      };
    };

    virtualisation.oci-containers.containers = {
      postgres = {
        image = "postgres:17";
        autoStart = true;
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "pass";
          POSTGRES_DB = "db";
        };
        ports = [
          "5432:5432"
        ];
        volumes = [
          "/var/lib/postgres-data:/var/lib/postgresql/data"
        ];
        extraOptions = [
          "--network=db-course-network"
        ];
      };

      pgadmin = {
        image = "dpage/pgadmin4:latest";
        autoStart = true;
        environment = {
          PGADMIN_DEFAULT_EMAIL = "admin@admin.com";
          PGADMIN_DEFAULT_PASSWORD = "admin";
          PGADMIN_LISTEN_PORT = "80";
        };
        ports = [ "5050:80" ];
        volumes = [
          "/var/lib/pgadmin-data:/var/lib/pgadmin"
        ];
        extraOptions = [
          "--network=db-course-network"
        ];
      };
    };
  };
}
