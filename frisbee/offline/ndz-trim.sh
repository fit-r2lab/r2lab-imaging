#!/bin/bash
# Trim raw images produced by ndz-extract.sh. Run as root on linux (loop mounts + chroot).
#
# usage: sudo ndz-trim.sh [options] image.raw [image.raw ...]
#
# By default each input is first COPIED (sparse) to <name>-trimmed.raw, and the copy is
# the one that gets trimmed; the original is never touched.
#   -o, --output-dir DIR   where to put the copies (default: next to each input)
#   -s, --suffix SUF       name the copy <name>SUF.raw (default: -trimmed)
#       --in-place         do not copy: trim the given file itself
#
# Inputs that already end in <suffix>.raw (default -trimmed.raw) are skipped when copying,
# so that `ndz-trim.sh /tmp/*.raw` is safe to re-run.
#
# environment knobs:
#   KEEP_KERNEL=7.0.0-30-generic   kernel to keep (default: the newest installed)
#   PURGE_SNAPD=1                  also remove snapd and every snap (default: leave alone)
#   KEEP_APT_LISTS=1               keep /var/lib/apt/lists (default: delete; apt update recreates them)
#   REMOVE_PACKAGES="emacs ..."    extra packages to remove (apt or dnf, whichever applies)
#
# What it does (debian/ubuntu and fedora):
#   - removes every kernel but one, with its modules, headers, initrd, /usr/src leftovers
#     (and the fedora 'rescue' kernel, which is generated for the machine it was installed on)
#   - autoremove of unneeded dependencies, package caches, apt lists
#   - truncates logs and journal, empties /tmp, /var/tmp, root's caches and history
# What it does NOT do: zero-fill free space (pointless on a 200G sparse fs),
# nor shrink the filesystem (inode tables are ~3G on a 200G ext4).

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

copy=1; outdir=; suffix=-trimmed
while [ $# -gt 0 ]; do
    case $1 in
        -o|--output-dir) [ -n "$2" ] || usage; outdir=$2; shift 2;;
        --output-dir=*) outdir=${1#*=}; shift;;
        -s|--suffix) [ -n "$2" ] || usage; suffix=$2; shift 2;;
        --suffix=*) suffix=${1#*=}; shift;;
        --in-place) copy=; shift;;
        -h|--help) usage;;
        --) shift; break;;
        -*) echo "unknown option $1"; usage;;
        *) break;;
    esac
done
[ $# -gt 0 ] || usage
[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

###### several inputs, or copy requested: prepare each file, then run ourselves on it in-place
if [ -n "$copy" ] || [ $# -gt 1 ]; then
    export NDZ_TRIM_SUMMARY=$(mktemp)
    [ -n "$outdir" ] && { mkdir -p "$outdir" || exit 1; }
    status=0
    for f in "$@"; do
        [ -f "$f" ] || { echo "$f: no such file"; status=1; continue; }
        target=$f
        if [ -n "$copy" ]; then
            # already a trimmed copy: skip it, so that `ndz-trim.sh *.raw` can be re-run safely
            case $f in *"$suffix".raw) echo "skipping $f (already a $suffix image)"; continue;; esac
            dir=${outdir:-$(dirname "$f")}
            target=$dir/$(basename "$f" .raw)$suffix.raw
            [ "$target" != "$f" ] || { echo "$f: copy would overwrite the input"; status=1; continue; }
            echo; echo "################################################################ $f -> $target"
            rm -f "$target"
            cp --sparse=always "$f" "$target" || { echo "copy failed"; status=1; continue; }
        else
            echo; echo "################################################################ $f (in place)"
        fi
        "$0" --in-place "$target" || status=1
    done
    echo; echo "=============== summary (used space in MB)"
    printf '%-40s %8s %8s %8s\n' image before after saved
    while read -r name b a; do
        printf '%-40s %8s %8s %8s\n' "$name" "$b" "$a" "$((b - a))"
    done < "$NDZ_TRIM_SUMMARY"
    rm -f "$NDZ_TRIM_SUMMARY"
    exit $status
fi

###### actual work, on one file, in place
raw=$1
[ -f "$raw" ] || { echo "$raw: no such file"; exit 1; }

m=$(mktemp -d)
dev=$(losetup --find --show --partscan "$raw") || exit 1
cleanup() {
    for d in dev/pts dev proc sys; do umount "$m/$d" 2>/dev/null; done
    umount "$m" 2>/dev/null; rmdir "$m" 2>/dev/null
    losetup -d "$dev"
}
trap cleanup EXIT

# first partition (or the bare device) holding a linux root
root=
for p in ${dev}p* $dev; do
    [ -b "$p" ] || continue
    mount "$p" "$m" 2>/dev/null || continue
    if [ -d "$m/etc" ] && [ -d "$m/usr" ]; then root=$p; break; fi
    umount "$m"
done
[ -n "$root" ] || { echo "no linux root filesystem found"; exit 1; }
. "$m/etc/os-release"; echo "trimming $root: $PRETTY_NAME"

for d in dev proc sys; do mount --bind /$d "$m/$d"; done
mount --bind /dev/pts "$m/dev/pts" 2>/dev/null
used() { df -B1M --output=used "$m" | tail -1 | tr -d ' '; }
before=$(used)
cr() { chroot "$m" env DEBIAN_FRONTEND=noninteractive "$@"; }

# keep track of the bootloader config: package removal triggers update-grub in a chroot on a loop device
grubcfg=
for g in boot/grub/grub.cfg boot/grub2/grub.cfg; do [ -f "$m/$g" ] && grubcfg=$g; done
[ -n "$grubcfg" ] && cp "$m/$grubcfg" /tmp/grub.cfg.before.$$

if [ -d "$m/var/lib/dpkg" ]; then
    ###### debian / ubuntu
    vers=$(chroot "$m" dpkg-query -W -f='${Package}\n' 'linux-image-[0-9]*' 'linux-image-unsigned-[0-9]*' \
           | sed -E 's/^linux-image-(unsigned-)?//' | sort -uV)
    keep=${KEEP_KERNEL:-$(echo "$vers" | tail -1)}
    echo "$vers" | grep -qx "$keep" || { echo "kernel $keep is not installed"; exit 1; }
    base=${keep%-*}                      # 7.0.0-30-generic -> 7.0.0-30 (headers meta package)
    echo "== keeping kernel $keep"
    pkgs=$(chroot "$m" dpkg-query -W -f='${Package}\n' 'linux-*' \
           | grep -E '^linux-(image|image-unsigned|modules|modules-extra|headers|tools|buildinfo|cloud-tools)-[0-9]' \
           | grep -Ev -- "-${base//./\\.}(-|\$)")
    echo "== purging:"; echo "$pkgs" | sed 's/^/   /'
    [ -n "$pkgs" ] && { cr apt-get purge -y $pkgs || echo "(warnings above may be expected in a chroot)"; }
    [ -n "$REMOVE_PACKAGES" ] && cr apt-get purge -y $REMOVE_PACKAGES
    echo "== autoremove"; cr apt-get autoremove --purge -y
    # packages removed earlier but with config files left behind
    rc=$(chroot "$m" dpkg -l | awk '/^rc/ {print $2}'); [ -n "$rc" ] && cr dpkg --purge $rc
    cr apt-get clean
    [ -n "$KEEP_APT_LISTS" ] || rm -rf "$m"/var/lib/apt/lists/*
    if [ -n "$PURGE_SNAPD" ]; then
        cr apt-get purge -y snapd; rm -rf "$m"/var/lib/snapd "$m"/snap "$m"/var/snap "$m"/root/snap
    fi
else
    ###### fedora / rpm
    keep=${KEEP_KERNEL:-$(chroot "$m" rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)}
    chroot "$m" rpm -q "kernel-core-$keep" >/dev/null || { echo "kernel $keep is not installed"; exit 1; }
    echo "== keeping kernel $keep"
    old=$(chroot "$m" rpm -q kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-devel \
          --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | grep -v 'not installed' | grep -vF -- "$keep")
    echo "== removing:"; echo "$old" | sed 's/^/   /'
    [ -n "$old" ] && { chroot "$m" dnf -y remove $old || echo "(dnf failed to remove old kernels)"; }
    [ -n "$REMOVE_PACKAGES" ] && chroot "$m" dnf -y remove $REMOVE_PACKAGES
    chroot "$m" dnf -y autoremove
    chroot "$m" dnf clean all
    rm -rf "$m"/var/cache/dnf/* "$m"/var/cache/libdnf5/* "$m"/var/cache/PackageKit/* "$m"/var/cache/ldconfig/* 2>/dev/null
    # the rescue kernel is built for the machine that installed the system, and costs ~100M
    rm -f "$m"/boot/*-rescue-* "$m"/boot/loader/entries/*-rescue.conf
    # make sure that we boot the kernel we kept
    if [ -x "$m/usr/sbin/grubby" ]; then
        chroot "$m" grubby --set-default="/boot/vmlinuz-$keep" || echo "grubby could not set the default"
    fi
fi

# whatever is left of the other kernels (empty dirs, generated files)
for d in "$m"/usr/lib/modules/*/; do
    v=$(basename "$d"); [ "$v" = "$keep" ] && continue
    echo "removing leftover modules dir $v"; rm -rf "$d"
done
for f in "$m"/boot/{vmlinuz,initrd.img,initramfs,System.map,config}-*; do
    [ -e "$f" ] || continue
    case $f in *"$keep"*) ;; *) echo "removing $f"; rm -f "$f";; esac
done
for f in "$m"/boot/loader/entries/*.conf; do
    [ -e "$f" ] || continue
    grep -q -- "$keep" "$f" || { echo "removing boot entry $f"; rm -f "$f"; }
done
rm -rf "$m"/var/lib/initramfs-tools/* 2>/dev/null   # only holds per-kernel hashes

# logs, journal, temporary stuff
rm -rf "$m"/var/log/journal/*
find "$m"/var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' -o -name '*.xz' \) -delete
find "$m"/var/log -type f -exec truncate -s 0 {} +
rm -rf "$m"/tmp/* "$m"/var/tmp/* "$m"/root/.cache "$m"/root/.bash_history "$m"/root/.lesshst "$m"/root/.viminfo
rm -rf "$m"/var/crash/* "$m"/var/cache/man/* 2>/dev/null

# what did the bootloader config become ?
if [ -f /tmp/grub.cfg.before.$$ ]; then
    echo "== $grubcfg diff (review!)"
    diff /tmp/grub.cfg.before.$$ "$m/$grubcfg" | head -40
    rm -f /tmp/grub.cfg.before.$$
fi
ls "$m"/boot "$m"/boot/loader/entries 2>/dev/null | sed 's/^/boot now: /'

after=$(used)
echo "== used space: ${before}M -> ${after}M"
[ -n "$NDZ_TRIM_SUMMARY" ] && echo "$(basename "$raw") $before $after" >> "$NDZ_TRIM_SUMMARY"
sync
# the final fsck needs the fs unmounted
for d in dev/pts dev proc sys; do umount "$m/$d" 2>/dev/null; done
umount "$m" && e2fsck -fn "$root"
