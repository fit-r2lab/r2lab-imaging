# Docker-enabled host images

Frisbee images (`docker` on ubuntu-26, `podman` on fedora-44) meant for
`rhubarbe docker load`, which then runs a user container on top of them.
The rhubarbe side (config, registries, image naming) is documented in
`DOCKER.md` in the rhubarbe repo; this is what an **image** must provide.

## Requirements

- docker is installed and starts at boot; the `docker` command exists
  (on fedora: package `podman-docker`, which wraps podman; rhubarbe always
  calls `docker`)
- the **host sshd listens on port 2222**, with root login by the same key
  as for regular nodes. Port 22 is left free for the container, which
  shares the host network. rhubarbe drives the node through 2222
  (`[docker] host_ssh_port`)
- `ss` is available (used to see whether something listens on port 22)
- systemd (`systemctl restart docker` is used to apply the registry mirror)
- kernel: whatever the experiments need from inside the container
  (modules, netns, ...); the container is privileged and sees the host's
  kernel

## What an image must NOT contain

Anything about registries or mirrors: rhubarbe writes
`/etc/docker/daemon.json` (or the podman `registries.conf.d` drop-in) at
load time, from `[docker] mirror`, so that moving the mirror does not require
rebuilding images. Other keys already in `daemon.json` are preserved.

## ssh into arbitrary container images

Images need not contain an sshd: rhubarbe can inject a static dropbear.
`dropbear/build-dropbear.sh` builds it (same architecture as the nodes);
point `[docker] dropbear` in rhubarbe.conf to the result.
