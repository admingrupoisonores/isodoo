# ISO ODOO (isOdoo)

*** PROJECT UNDER DEVELOPMENT. NOT READY FOR PRODUCTION ***


A lightweight image for running Odoo from 6.0 to the moon! Strongly inspired by the doodba project and the official Odoo image.


## :ballot_box_with_check: Features

- Installation from source code
- Detect missing modules at build time
- Automatically obtains and downloads modules dependencies
- Strong use of virtual environments

## :page_facing_up: Documentation

To configure Odoo, simply use environment variables with the prefix ```OCONF_{Param Name}```. Example for changing workers: ```OCONF_workers=4```.

** On Odoo 6.1 you can use environment variables with the prefix ```OWCONF_{Param Name}``` (taking into account that the underscores will be replaced by dots).

### Other Env. Variables

| Name | Description | Required | Default |
|----------------|-------------|-------------|-------------|
| GITHUB_TOKEN | User token to use with git-aggregator | No | "" |
| GIT_DEPTH_NORMAL | The default depth of commits | Yes | 1 |
| GIT_DEPTH_MERGE | The default depth of commits when cloning with merges | Yes | 500 |
| EXT_DEPS_CONSTRAINTS | The constraints for the dependency names (old_name:new_name) separated by commas | No | "" |

** Check the Dockerfile for more configuration variables.


### Default Ports

| Port | Odoo Version |Description |
|----------------|-------------|-------------|
| 8069 | 6.1+ | Default port for HTTP and XML-RPC (web interface and API) |
| 8071 | 6.0+ | **Optional** port for XML-RPC (depends on configuration) |
| 8072 | 6.0+ | Port for long polling (real-time notifications, such as chat) |
| 8080 | 6.0 | [6.0 Only] Default port for HTTP and XML-RPC (web interface and API) |


### Docker Compose
```yml
services:
  odoo:
    build:
      context: .
      additional_contexts:
        deps: ./deps
        addons: ./addons
    depends_on:
      db:
        condition: service_healthy
    ports:
      - '8069:8069'
    networks:
      - frontend
      - dbnet
    environment:
      ODOO_VERSION: 19.0
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
