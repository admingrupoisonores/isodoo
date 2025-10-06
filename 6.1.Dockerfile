# The system version is limited by:
#  - lxml: Requires specific versions of libxml2==2.9.1 and libxslt==1.1.28
FROM debian:buster-slim

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive


# Install system packages
ARG TARGETARCH
ARG ODOO_PKGS="fonts-liberation libpq-dev libjpeg-dev zlib1g-dev libssl-dev libc6-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev"

RUN set -eux; \
    rm /etc/apt/sources.list; \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list.d/buster.list; \
    echo "deb http://archive.debian.org/debian buster main" >> /etc/apt/sources.list.d/buster.list; \
    apt-get update && apt-get install -y --no-install-recommends \
        # Common
        fontconfig \
        ca-certificates \
        git \
        curl \
        # By Conf
        ${ODOO_PKGS} \
        # PyEnv
        build-essential \
        patch; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    fc-cache -fv;


# Create the runtime user
ARG USER_ODOO_UID=7777
ARG USER_ODOO_GID=7777

RUN set -eux; \
    groupadd --gid ${USER_ODOO_GID} --system odoo; \
    useradd \
        --home-dir /home/odoo \
        --system \
        --uid ${USER_ODOO_UID} \
        --gid ${USER_ODOO_GID} \
        -s /bin/bash \
        odoo; \
    mkdir -p /home/odoo /etc/odoo /opt/odoo /var/lib/odoo; \
    chown -R odoo:odoo /home/odoo /opt/odoo /etc/odoo /var/lib/odoo;


# Change to runtime user
USER odoo


# Install & activate PyEnv
ENV PATH="/home/odoo/.pyenv/bin:/home/odoo/.pyenv/shims:$PATH" \
    PYENV_ROOT="/home/odoo/.pyenv" \
    PYENV_VIRTUALENV_DISABLE_PROMPT=1 \
    ODOO_PYTHON_VERSION=2.7 \
    SYSTEM_PYTHON_VERSION=3
ENV PYTHON_SYSTEM_BIN_NAME=python${SYSTEM_PYTHON_VERSION} \
    PYTHON_ODOO_BIN_NAME=python${ODOO_PYTHON_VERSION}

RUN set -eux; \
    curl -fsSL https://pyenv.run | bash; \
    eval "$(pyenv init --path)"; \
    eval "$(pyenv init -)"; \
    eval "$(pyenv virtualenv-init -)"; \
    pyenv install ${SYSTEM_PYTHON_VERSION} ${ODOO_PYTHON_VERSION}; \
    pyenv global ${SYSTEM_PYTHON_VERSION} ${ODOO_PYTHON_VERSION}; \
    rm -rf ${PYENV_ROOT}/cache/*;


### SYSTEM PYTHON ENV
WORKDIR /home/odoo

# Install System PIP & Extra dependencies
# hadolint ignore=SC1091
RUN set -eux; \
    $PYTHON_SYSTEM_BIN_NAME -m venv ~/.venv; \
    . .venv/bin/activate; \
    pip install --no-cache-dir --upgrade pip; \
    pip install --no-cache-dir click-odoo-contrib git-aggregator pyyaml psycopg2; \
    pip cache purge; \
    deactivate;


### ODOO PYTHON ENV
WORKDIR /opt/odoo

ARG ODOO_EXTRA_PIP_PKGS="pyOpenSSL==17.5.0"

# Install Odoo PIP & Extra dependencies
# hadolint ignore=SC1091
RUN set -eux; \
    curl -L -o get-pip.py https://bootstrap.pypa.io/pip/${ODOO_PYTHON_VERSION}/get-pip.py; \
    $PYTHON_ODOO_BIN_NAME get-pip.py; \
    rm -f get-pip.py; \
    $PYTHON_ODOO_BIN_NAME -m pip install --no-cache-dir --upgrade pip; \
    $PYTHON_ODOO_BIN_NAME -m pip install --no-cache-dir virtualenv; \
    $PYTHON_ODOO_BIN_NAME -m virtualenv /opt/odoo/.venv; \
    . .venv/bin/activate; \
    pip install --no-cache-dir ${ODOO_EXTRA_PIP_PKGS}; \
    pip cache purge; \
    deactivate;

# Install PyXML (used by python zsi package)
# hadolint ignore=DL3003,SC1091
RUN set -ex; \
    curl -L -o PyXML.tar.gz https://github.com/actmd/PyXML/archive/refs/tags/0.8.4.tar.gz; \
    tar -xzvf PyXML.tar.gz; \
    . .venv/bin/activate; \
    cd ./PyXML-0.8.4; \
    $PYTHON_ODOO_BIN_NAME setup.py build --with-xslt; \
    $PYTHON_ODOO_BIN_NAME setup.py install; \
    deactivate; \
    rm -f PyXML.tar.gz; \
    rm -rf ./PyXML-0.8.4;


# System Post-Configurations
USER root

COPY recipes/6.1/requirements.txt /opt/odoo/requirements.txt
COPY docker-entrypoint.sh /usr/local/sbin/
COPY tools/exec_env.sh /usr/local/sbin/exec_env
COPY tools/generate_config.py /usr/local/sbin/generate_config
COPY tools/create_addons_symlinks.py /usr/local/sbin/create_addons_symlinks
COPY tools/wait_for_psql.py /usr/local/sbin/wait_for_psql
RUN chmod +x \
    /usr/local/sbin/docker-entrypoint.sh \
    /usr/local/sbin/exec_env \
    /usr/local/sbin/generate_config \
    /usr/local/sbin/create_addons_symlinks \
    /usr/local/sbin/wait_for_psql;


# Change to runtime user
USER odoo


# Install Odoo + Extras
ONBUILD ENV LC_ALL=C.UTF-8 \
            LANG=C.UTF-8 \
            ODOO_VERSION=6.1 \
            GIT_DEPTH_NORMAL=1 \
            GIT_DEPTH_MERGE=500 \
            OCONF_addons_path="/var/lib/odoo/core,/var/lib/odoo/extra" \
            OCONF_workers=2

ONBUILD COPY ./deps/apt.txt /opt/odoo/apt.txt
ONBUILD COPY ./deps/pip.txt /opt/odoo/pip.txt
ONBUILD COPY ./addons/repos.yaml /opt/odoo/repos.yaml
ONBUILD COPY ./addons/addons.yaml /opt/odoo/addons.yaml

ONBUILD USER root

ONBUILD RUN set -ex; \
    apt-get update; \
    cat /opt/odoo/apt.txt | apt-get install -y --no-install-recommends;

ONBUILD USER odoo

ONBUILD WORKDIR /opt/odoo

ONBUILD RUN set -ex; \
            . ~/.venv/bin/activate; \
            gitaggregate -c repos.yaml --expand-env; \
            chmod +x /opt/odoo/odoo/openerp-server; \
            create_addons_symlinks; \
            deactivate;

ONBUILD WORKDIR /opt/odoo/odoo

# hadolint ignore=SC1091,DL3042
ONBUILD RUN set -ex; \
    . ../.venv/bin/activate; \
    printf '#!/bin/bash\n/opt/odoo/odoo/openerp-server "$@"' > ../.venv/bin/odoo; \
    chmod +x ../.venv/bin/odoo; \
    mv /opt/odoo/requirements.txt .;\
    pip install --no-binary psycopg2 -r requirements.txt; \
    pip install -r /opt/odoo/pip.txt; \
    # Cleanup
    pip cache purge; \
    find .. -name "build" -type d -exec rm -rf {} +; \
    find .. -name "*.egg-info" -type d -exec rm -rf {} +; \
    find .. -name "*.pyc" -exec rm -f {} +; \
    rm -rf /tmp/*; \
    # Post-configurations
    python -m compileall /var/lib/odoo/; \
    # Ensure all is working
    odoo --version; \
    deactivate;


ONBUILD WORKDIR /opt/odoo


# Expose Odoo services
EXPOSE 8069 8070 8071


# Run
ENTRYPOINT ["/usr/local/sbin/docker-entrypoint.sh"]
CMD ["odoo", "--config", "/etc/odoo/odoo.conf"]
