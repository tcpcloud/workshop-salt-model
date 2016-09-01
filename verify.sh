#!/usr/bin/env bash

# generate and validate reclass-salt-model
# expected to be executed in isolated environment, ie: docker, kitchen-docker

export LC_ALL=C

set -e
if [[ $DEBUG =~ ^(True|true|1|yes)$ ]]; then
    set -x
fi

## Overrideable options
COOKIECUTTER_DIR=${COOKIECUTTER_DIR:-/srv/cookiecutter-salt-model}
#MASTER_HOSTNAME=${MASTER_HOSTNAME:-$(basename $(ls nodes/cfg01*.yml|head -1) .yml)}
MASTER_HOSTNAME=${HOSTNAME:-salt-model-test.ci.local}
DOCKER_IMAGE=${DOCKER_IMAGE:-"ubuntu:14.04"}
RECLASS_ROOT=${RECLASS_ROOT:-$(pwd)}
SALT_OPTS="${SALT_OPTS} --retcode-passthrough --force-color"

## Functions
log_info() {
    echo "[INFO] $*"
}

log_err() {
    echo "[ERROR] $*" >&2
}

_atexit() {
    RETVAL=$?
    trap true INT TERM EXIT

    if [ $RETVAL -ne 0 ]; then
        log_err "Execution failed"
    else
        log_info "Execution successful"
    fi

    return $RETVAL
}


## Main
trap _atexit INT TERM EXIT

log_info "Generate reclass from cookiecutter"

mkdir -p /srv/salt/reclass
cp -a /tmp/kitchen/* /srv/salt/reclass

log_info "Setting up Salt master"
# TODO: remove grains.d hack when fixed in formula
mkdir -p /etc/salt/grains.d && touch /etc/salt/grains.d/dummy
[ ! -d /etc/salt/pki/minion ] && mkdir -p /etc/salt/pki/minion
[ ! -d /etc/salt/master.d ] && mkdir -p /etc/salt/master.d || true
cat <<-'EOF' > /etc/salt/master.d/master.conf
  file_roots:
    base:
    - /usr/share/salt-formulas/env
  pillar_opts: False
  open_mode: True
  reclass: &reclass
    storage_type: yaml_fs
    inventory_base_uri: /srv/salt/reclass
  ext_pillar:
    - reclass: *reclass
  master_tops:
    reclass: *reclass
EOF


log_info "Setting up reclass"
[ -d /srv/salt/reclass/classes/service ] || mkdir -p /srv/salt/reclass/classes/service || true
for i in /usr/share/salt-formulas/reclass/service/*; do
  [ -e /srv/salt/reclass/classes/service/$(basename $i) ] || ln -s $i /srv/salt/reclass/classes/service/$(basename $i)
done

[ ! -d /etc/reclass ] && mkdir /etc/reclass || true
cat <<-'EOF' > /etc/reclass/reclass-config.yml
  storage_type: yaml_fs
  pretty_print: True
  output: yaml
  inventory_base_uri: /srv/salt/reclass
EOF

log_info "Setting up Salt minion"
apt-get install -y salt-minion
[ ! -d /etc/salt/minion.d ] && mkdir -p /etc/salt/minion.d || true
cat <<-EOF > /etc/salt/minion.d/minion.conf
  id: ${MASTER_HOSTNAME}
  master: localhost
EOF

log_info "Starting Salt master service"
DETACH=1 /usr/bin/salt-master &
sleep 3

log_info "Running states to finish Salt master setup"
reclass-salt -p ${MASTER_HOSTNAME}
salt-call ${SALT_OPTS} state.show_top

if [[ $SALT_MASTER_FULL =~ ^(True|true|1|yes)$ ]]; then
    # TODO: can fail on "hostname: you must be root to change the host name"
    salt-call ${SALT_OPTS} state.sls linux,openssh || true
    salt-call ${SALT_OPTS} state.sls salt,reclass
else
    salt-call ${SALT_OPTS} state.sls reclass.storage.node
fi

NODES=$(ls /srv/salt/reclass/nodes/_generated)
for node in ${NODES}; do
    node=$(basename $node .yml)
    log_info "Testing node ${node}"
    reclass-salt -p ${node}
    salt-call ${SALT_OPTS} --id=${node} state.show_lowstate
done
