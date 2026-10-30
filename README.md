# r2lab-images

Tooling and notes for the images used on the R2lab testbed. There are two
kinds of them, and not much of this is actively used any more.

## frisbee images (`frisbee/`)

The `.ndz` images that `rhubarbe load` and `rhubarbe save` deal with. They are
stored in `/var/lib/rhubarbe-images`, on both faraday and distrait.

- `build-image.py` builds a new image out of an existing one, by loading it on
  a node, running scripts on it (with `build-image.sh`), and saving the result.
  `build-image.md` has the usage, and `all-images.sh` is a wrapper that builds
  the OAI and mosaic images. **Unmaintained**: it has not been used since 2019,
  and as of today it no longer imports with a current `apssh`.
- `pull-from-preplab.sh` syncs `/var/lib/rhubarbe-images` from
  `preplab.pl.sophia.inria.fr`, which is an alias for distrait, onto faraday.
  `push-to-preplab.sh` is a symlink to it, and the script acts according to
  its own name. It refuses to run anywhere but on faraday.
- `notes/` is the hand-written logbook of image work, newest entries first.

The scripts that get pushed to the nodes live in `r2lab-embedded/shell/`,
not here. Set `R2LAB_EMBEDDED` to where that repo is cloned if it is not in
the default location (`/root/r2lab-embedded` on faraday, otherwise
`~/git/r2lab-embedded`).

## docker images (`docker/`)

At some point the idea was to provide a minimal frisbee image with only docker
in it, so that experimenters could leverage docker images instead. These are
the Dockerfiles for a few images published on Docker Hub as `fitr2lab/*`.

- `build-and-push.sh [-b] [-f] [-t tag] subdir` builds one of them and pushes it.
  It copies `r2lab-embedded/shell/*.sh` in the build context first, see
  `R2LAB_EMBEDDED` above.
- `baleine/`, `ubuntu16/` and `openairinterface5g/`.
- `docker-fedora32-r2lab/` and `docker-ubuntu18-r2lab/`: minimal base images with
  the networking and kernel-module tools, from the former `non-standard-nodes`
  in `r2lab-misc`.
- `openair-cn/` **does not work**: phpmyadmin cannot be built without systemd.
  It is kept for the record.

## History

This was extracted from `r2lab-embedded` (`imaging/` and `docker-images/`) and
from `r2lab-misc` (`rhubarbe-images/`), with their history.
