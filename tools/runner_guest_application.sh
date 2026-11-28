#!/bin/bash
# Trusted bootstrap, executed only as root inside a new isolated disposable VM.
set -euo pipefail
test "$(id -u)" = 0
test "$(systemd-detect-virt)" = kvm
test ! -S /var/run/docker.sock
export DEBIAN_FRONTEND=noninteractive
apt-get -y -qq install git build-essential postgresql-client uidmap dbus-user-session slirp4netns > /root/application-packages.log 2>&1
install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --max-time 30 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod 644 /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<'SOURCE'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
SOURCE
apt-get -qq -o APT::Update::Error-Mode=any -o Acquire::Retries=0 -o Acquire::http::Timeout=20 update
# Packages must never start a rootful daemon, even briefly during installation.
test ! -e /usr/sbin/policy-rc.d
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-ce-rootless-extras > /root/docker-packages.log 2>&1
systemctl mask docker.service docker.socket containerd.service
rm /usr/sbin/policy-rc.d
test ! -S /var/run/docker.sock
! systemctl is-active --quiet docker.service
! systemctl is-active --quiet containerd.service
! id -nG runner | grep -Eq 'sudo|docker|libvirt'
python3 - <<'PY'
from pathlib import Path
for name in ('subuid', 'subgid'):
    entries = [line.split(':') for line in (Path('/etc') / name).read_text().splitlines()]
    assert any(user == 'runner' and int(count) >= 65536 for user, start, count in entries)
PY
runner_uid="$(id -u runner)"
loginctl enable-linger runner
systemctl start "user@${runner_uid}.service"
runuser -u runner -- env XDG_RUNTIME_DIR="/run/user/${runner_uid}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${runner_uid}/bus" dockerd-rootless-setuptool.sh install > /root/rootless-setup.log 2>&1
runuser -u runner -- env XDG_RUNTIME_DIR="/run/user/${runner_uid}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${runner_uid}/bus" systemctl --user enable --now docker.service
runuser -u runner -- env DOCKER_HOST="unix:///run/user/${runner_uid}/docker.sock" docker info --format '{{json .SecurityOptions}}' | python3 -c 'import json,sys; assert "name=rootless" in json.load(sys.stdin)'
test ! -S /var/run/docker.sock
test ! -f /var/run/reboot-required
