# ISO ODOO (isOdoo)

*** PROJECT UNDER DEVELOPMENT. NOT READY FOR PRODUCTION ***


A lightweight image for running Odoo from 6.0 to the moon! Strongly inspired by the [Doodba project](https://github.com/Tecnativa/doodba/) and the official [Odoo image](https://github.com/odoo/docker).


## :ballot_box_with_check: Features

- Installation from source code
- Detect missing modules at build time
- Automatically obtains and downloads modules dependencies
- Strong use of virtual environments (using UV in 14.0+)

## :page_facing_up: Documentation

To configure Odoo, simply use environment variables with the prefix ```OCONF_{Param Name}```. Example for changing workers: ```OCONF_workers=4```.

** On Odoo 6.x you can use environment variables with the prefix ```OWCONF_{Param Name}``` (taking into account that the underscores will be replaced by dots).

### Build Arguments

| Name | Description |
|----------------|-------------|
| WKHTMLTOPDF_PKGS | Paquetes del sistema necesarios para usar WKHTMLTOPDF |
| ODOO_PKGS | Paquetes del sistema necesarios para usar Odoo  |
| WKHTMLTOPDF_VERSION | Version de WKHTMLTOPDF a instalar |
| WKHTMLTOPDF_BASE_DEBIAN_VER | Version de sistema de WKHTMLTOPDF a instalar |
| USER_ODOO_UID | UID del usuario Odoo |
| USER_ODOO_GID | GID del usuario Odoo |
| NVM_VERSION | Version de NVM a usar |
| NODE_VERSION | Versión de Node a instalar |
| ODOO_NPM_PKGS | Paqueres de Necesario para usar Odoo |
| ODOO_PYTHON_VERSION | Version de Python a instalar para Odoo |
| SYSTEM_PYTHON_VERSION| Version de Python a instalar para el sistema |

### -ONBUILD- Build Arguments

| Name | Description |
|----------------|-------------|
| EXT_DEPS_OVERRIDES | The overrides for the module external dependency names (old_name:new_name) separated by commas (Solo es útil si se usa AUTO_DOWNLOAD_DEPENDENCIES) |
| ODOO_VERSION | La version de Odoo a instalar  |
| VERIFY_MISSING_MODULES | Indica si se verifica que todos los modulos (y los otros modulos de lo que depende) están disponibles |
| AUTO_DOWNLOAD_DEPENDENCIES | Indica si se deben descargar todas las dependencias externas de los modulos disponibles |
| AUTO_FILL_REPOS | Indica si se debe ajustar el repos.yaml a lo que se usa en addons.yaml (solo repositorios OCA) |

### -ONBUILD- Environment Variables

| Name | Description | Required | Default |
|----------------|-------------|-------------|-------------|
| GITHUB_TOKEN | User token to use with git-aggregator | No | "" |
| GIT_DEPTH_NORMAL | The default depth of commits | Yes | 1 |
| GIT_DEPTH_MERGE | The default depth of commits when cloning with merges | Yes | 500 |
| EXT_DEPS_OVERRIDES | The overrides for the dependency names (old_name:new_name) separated by commas | No | "" |

** Check the Dockerfile for more configuration variables/args.


### Default Ports

| Port | Odoo Version |Description |
|----------------|-------------|-------------|
| 8069 | 6.1+ | Default port for HTTP and XML-RPC (web interface and API) |
| 8071 | 6.0+ | **Optional** port for XML-RPC (depends on configuration) |
| 8072 | 6.0+ | Port for long polling (real-time notifications, such as chat) |
| 8080 | 6.0 | [6.0 Only] Default port for HTTP and XML-RPC (web interface and API) |


### Custom Dockerfile
```Dockerfile
ARG ODOO_VERSION
FROM isodoo:${ODOO_VERSION} AS isodoo-runtime
FROM isodoo-runtime AS isodoo-runtime-private
COPY --from=private --chown=odoo:odoo / /var/lib/odoo/private
ENV OCONF_addons_path="${OCONF_addons_path},/var/lib/odoo/private"
```

### Docker Compose
```yml
services:
  odoo:
    build:
      context: .
      args:
        ODOO_VERSION: 19.0
      additional_contexts:
        deps: ./deps
        addons: ./addons
        private: ./private
    depends_on:
      db:
        condition: service_healthy
    ports:
      - '8069:8069'
    networks:
      - frontend
      - dbnet
    environment:
      OCONF_log_level: debug
      OCONF_db_filter: odoodb$
      OCONF_db_user: odoo
      OCONF_db_password: odoo
      OCONF_db_host: odoo-db
      OCONF_db_name: odoodb
      OCONF_proxy_mode: false
    hostname: odoo

  db:
    image: postgres:18.0-alpine
    networks:
      - dbnet
    environment:
      POSTGRES_DB: odoodb
      POSTGRES_PASSWORD: odoo
      POSTGRES_USER: odoo
      POSTGRES_INITDB_ARGS: --locale=C --encoding=UTF8
    hostname: odoo-db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U odoo -d odoodb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s


networks:
  frontend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.host_binding_ipv4: 127.0.0.1
  dbnet:
```
