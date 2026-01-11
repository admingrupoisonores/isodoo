ARG ODOO_VERSION
FROM test:docker-isodoo-${ODOO_VERSION} AS isodoo-runtime
FROM isodoo-runtime AS isodoo-runtime-private
# hadolint ignore=DL3022
COPY --from=private --chown=odoo:odoo / /var/lib/odoo/private
ENV OCONF_addons_path="${OCONF_addons_path},/var/lib/odoo/private"
