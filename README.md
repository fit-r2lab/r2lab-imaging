# r2lab-imaging

Tooling and notes for the images used on the R2lab testbed. There are two
kinds of them, and not much of this is actively used any more.

## frisbee images (`frisbee/`)

The `.ndz` images that `rhubarbe load` and `rhubarbe save` deal with. They are
stored in `/var/lib/rhubarbe-images`, on faraday (the reference), and are
backed up elsewhere, see below.

### Layout of the image repository, and why

The number of images keeps growing, and it has reached the point where
neither preplab nor the two other backup locations (bigjack and bigjohn) have
enough room to hold all of them. Hence a tree structure:

- the images that matter live at the **toplevel** of
  `/var/lib/rhubarbe-images`;
- the rest is moved into `archive*` subfolders (e.g. `archive`, `archive-oai`).

How rhubarbe deals with this:

- every image under the repository, subfolders included, is visible to and
  loadable with `rhubarbe load` and `rhubarbe resolve`;
- `rhubarbe images` only shows the toplevel images by default; use `--all` to
  see everything, or do a search, in which case subfolders are searched too.

### Backups

These are done on faraday by the `backup-faraday-images` systemd service,
triggered daily at 04:00 by the matching timer (both in `deploy/`; see
`deploy/update.sh` for how they get deployed). The service rsyncs
`/var/lib/rhubarbe-images` to:

- **bigjack** and **bigjohn** (`/containers/backup-faraday-images`): all of it,
  except the `archive*` subfolders, with `--delete`;
- **distrait**, a.k.a. preplab: the toplevel `*.ndz` images only, with
  `--delete`.

So the `archive*` subfolders are not backed up at all. On preplab, the images
that come from faraday land at the toplevel, which is why preplab keeps its
own images in the `prep/` subfolder: as the sync does not touch
subfolders, they do not get trashed by `--delete`. Those are the ones that
`pull-from-preplab.sh` brings back onto faraday.

### Tooling

**Unmaintained**: it has not been used since 2019,
  and as of today it no longer imports with a current `apssh`.

- `build-image.py` builds a new image out of an existing one, by loading it on
  a node, running scripts on it (with `build-image.sh`), and saving the result.
  `build-image.md` has the usage, and `all-images.sh` is a wrapper that builds
  the OAI and mosaic images.
- `pull-from-preplab.sh` pulls the `prep/` subfolder of
  `preplab.pl.sophia.inria.fr` (an alias for distrait) into
  `/var/lib/rhubarbe-images/prep/` on faraday. It does not use `--delete`, as
  images can be saved directly on faraday. It refuses to run anywhere but on
  faraday. There is no push script any more: pushing is done by the backup
  timer described below.
- `notes/` is the hand-written logbook of image work, newest entries first.

The scripts that get pushed to the nodes live in `r2lab-embedded/shell/`,
not here. Set `R2LAB_EMBEDDED` to where that repo is cloned if it is not in
the default location (`/root/r2lab-embedded` when running as root,
otherwise `~/git/r2lab-embedded`).

## docker images (`docker/`)

**Unmaintained**

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

### Docker-enabled host images (current)

Not stale, unlike the rest of this section: the host images used by
`rhubarbe docker load` (frisbee images with docker or podman, and the host
sshd on port 2222) are described in `docker/host-images.md`, and
`docker/dropbear/build-dropbear.sh` builds the static sshd that rhubarbe
injects in containers whose image has none.

## History

This was extracted from `r2lab-embedded` (`imaging/` and `docker-images/`) and
from `r2lab-misc` (`rhubarbe-images/`), with their history.
