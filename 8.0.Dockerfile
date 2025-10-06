# The system version is limited by:
#  - lxml: Requires specific versions of libxml2==2.9.1 and libxslt==1.1.28
#  - WKHTMLTOPDF: requires libssl1.1
FROM debian:buster-slim

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive


# Install system packages
ARG TARGETARCH
ARG WKHTMLTOPDF_PKGS="libfreetype6 libjpeg62-turbo libpng16-16 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base"
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
        ${WKHTMLTOPDF_PKGS} \
        ${ODOO_PKGS} \
        # PyEnv
        build-essential \
        patch; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    fc-cache -fv;


# Install WKHTMLTOX
ARG WKHTMLTOPDF_VERSION=0.12.1.4-2
ARG WKHTMLTOPDF_BASE_DEBIAN_VER=buster

RUN set -eux; \
    curl -L -o wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.${WKHTMLTOPDF_BASE_DEBIAN_VER}_${TARGETARCH}.deb; \
    dpkg -i ./wkhtmltox.deb || apt-get install --no-install-recommends -f -y; \
    apt-get install --no-install-recommends -y ./wkhtmltox.deb; \
    rm -rf /tmp/*;


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


# Install NodeJS & Depedencies
ARG NVM_VERSION=v0.40.3
ARG NODE_VERSION=0.12.18
ARG ODOO_NPM_PKGS="rtlcss less@1.7.5 less-plugin-clean-css"

RUN set -ex; \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash; \
    . ~/.nvm/nvm.sh; \
    nvm install ${NODE_VERSION}; \
    nvm use ${NODE_VERSION}; \
    npm install -g ${ODOO_NPM_PKGS};


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

ARG ODOO_EXTRA_PIP_PKGS="pyinotify pyOpenSSL"

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


# System Post-Configurations
USER root

COPY recipes/8.0/constraints.txt /opt/odoo/constraints.txt
COPY docker-entrypoint.sh /usr/local/sbin/
COPY tools/exec_env.sh /usr/local/sbin/exec_env
COPY tools/generate_config.py /usr/local/sbin/generate_config
COPY tools/create_addons_symlinks.py /usr/local/sbin/create_addons_symlinks
COPY tools/wait_for_psql.py /usr/local/sbin/wait_for_psql
RUN set -ex; \
    chmod +x \
        /usr/local/sbin/docker-entrypoint.sh \
        /usr/local/sbin/exec_env \
        /usr/local/sbin/generate_config \
        /usr/local/sbin/create_addons_symlinks \
        /usr/local/sbin/wait_for_psql;


# Change to runtime user
USER odoo


# Verifications
RUN set -ex; \
    . ~/.nvm/nvm.sh; \
    wkhtmltopdf --version; \
    node --version;


# Install Odoo + Extras
ONBUILD ENV LC_ALL=C.UTF-8 \
            LANG=C.UTF-8 \
            ODOO_VERSION=8.0 \
            GIT_DEPTH_NORMAL=1 \
            GIT_DEPTH_MERGE=500 \
            OCONF_addons_path="/var/lib/odoo/core,/var/lib/odoo/extra" \
            OCONF_workers=2

ONBUILD COPY ./deps/apt.txt /opt/odoo/apt.txt
ONBUILD COPY ./deps/pip.txt /opt/odoo/pip.txt
ONBUILD COPY ./deps/npm.txt /opt/odoo/npm.txt
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
            chmod +x /opt/odoo/odoo/odoo.py /opt/odoo/odoo/openerp-server /opt/odoo/odoo/openerp-gevent; \
            create_addons_symlinks; \
            deactivate; \
            . ~/.nvm/nvm.sh; \
            cat /opt/odoo/npm.txt | npm install -g;

ONBUILD WORKDIR /opt/odoo/odoo

# hadolint ignore=SC1091,DL3042
ONBUILD RUN set -ex; \
    . ../.venv/bin/activate; \
    printf '#!/bin/bash\n/opt/odoo/odoo/odoo.py "$@"' > ../.venv/bin/odoo; \
    printf '#!/bin/bash\n/opt/odoo/odoo/openerp-server "$@"' > ../.venv/bin/openerp-server; \
    printf '#!/bin/bash\n/opt/odoo/odoo/openerp-gevent "$@"' > ../.venv/bin/openerp-gevent; \
    chmod +x ../.venv/bin/odoo ../.venv/bin/openerp-server ../.venv/bin/openerp-gevent; \
    mv /opt/odoo/constraints.txt .;\
    pip install --no-binary psycopg2 -r requirements.txt -c constraints.txt; \
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
EXPOSE 8069 8071 8072


# Run
ENTRYPOINT ["/usr/local/sbin/docker-entrypoint.sh"]
CMD ["odoo", "--config", "/etc/odoo/odoo.conf"]
