#!/bin/bash
# Turn raw whole-disk images (from ndz-extract.sh / ndz-trim.sh) back into frisbee .ndz images.
# Same imagezip invocation as rhubarbe save, only the disk is a loop device instead of /dev/sda.
# Run as root on linux.
#
# usage: sudo ndz-rewrap.sh [-o|--output-dir DIR] [-f|--force] image.raw [image.raw ...]
#
# each image.raw produces DIR/image.ndz (DIR defaults to next to the input);
# an existing output is left alone unless --force.
# imagezip location can be overridden with IMAGEZIP=/path/to/imagezip

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

outdir=; force=
while [ $# -gt 0 ]; do
    case $1 in
        -o|--output-dir) [ -n "$2" ] || usage; outdir=$2; shift 2;;
        --output-dir=*) outdir=${1#*=}; shift;;
        -f|--force) force=1; shift;;
        -h|--help) usage;;
        --) shift; break;;
        -*) echo "unknown option $1"; usage;;
        *) break;;
    esac
done
[ $# -gt 0 ] || usage
[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }
[ -z "$outdir" ] || mkdir -p "$outdir" || exit 1

imagezip=${IMAGEZIP:-/root/r2lab-misc/frisbee-binaries-inria/imagezip}
[ -x "$imagezip" ] || { echo "imagezip not found at $imagezip: set IMAGEZIP"; exit 1; }
echo "using $imagezip"

status=0
for raw in "$@"; do
    [ -f "$raw" ] || { echo "$raw: no such file"; status=1; continue; }
    out=${outdir:-$(dirname "$raw")}/$(basename "$raw" .raw).ndz
    if [ -e "$out" ] && [ -z "$force" ]; then
        echo "$out exists, use --force to overwrite"; status=1; continue
    fi
    echo "=== $raw -> $out"
    # imageunzip only writes up to the last allocated block, but imagezip wants to see the whole
    # disk the partition table describes (else: "makeranges: Assertion inputmaxsec > offset").
    # So grow the sparse file (no disk space needed) up to the end of the last partition.
    need=$(sfdisk -d "$raw" 2>/dev/null | sed -n 's/.*start= *\([0-9]*\), size= *\([0-9]*\).*/\1 \2/p' \
           | awk '{e=($1+$2)*512; if (e>m) m=e} END {print m+0}')
    have=$(stat -c %s "$raw")
    if [ "$need" -gt "$have" ]; then
        echo "growing $raw from $have to $need bytes (sparse)"
        truncate -s "$need" "$raw" || { status=1; continue; }
    fi
    # whole disk, like rhubarbe save on /dev/sda; no partscan needed, imagezip reads the partition table
    dev=$(losetup --find --show --read-only "$raw") || { status=1; continue; }
    # same options as rhubarbe save, with a file instead of netcat on the other end of the pipe
    # imagezip talks on stderr: keep it, and show it (it has the stats when all goes well, the reason when not)
    if "$imagezip" -o -z1 "$dev" - > "$out.tmp" 2> "$out.log"; then
        mv "$out.tmp" "$out"
        tail -5 "$out.log"
        ls -lh "$out"
    else
        echo "$raw: imagezip failed (exit $?), its messages:"; cat "$out.log"
        rm -f "$out.tmp"; status=1
    fi
    losetup -d "$dev"
done
exit $status
