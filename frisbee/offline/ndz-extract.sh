#!/bin/bash
# Expand frisbee .ndz images into sparse raw files, without any physical node.
# Needs imageunzip (emulab frisbee tools); meant to run on faraday.
#
# usage: ndz-extract.sh [-o|--output-dir DIR] image.ndz [image.ndz ...]
#
# each image.ndz produces DIR/image.raw (same basename, .raw instead of .ndz);
# DIR defaults to the current directory. The raw files are sparse: free blocks
# are holes, so use `du -h` (not ls -l) to see the space they really use.
# imageunzip location can be overridden with IMAGEUNZIP=/path/to/imageunzip

usage() { echo "usage: $0 [-o|--output-dir DIR] image.ndz [image.ndz ...]"; exit 1; }

outdir=.
while [ $# -gt 0 ]; do
    case $1 in
        -o|--output-dir) [ -n "$2" ] || usage; outdir=$2; shift 2;;
        --output-dir=*) outdir=${1#*=}; shift;;
        -h|--help) usage;;
        --) shift; break;;
        -*) echo "unknown option $1"; usage;;
        *) break;;
    esac
done
[ $# -gt 0 ] || usage
mkdir -p "$outdir" || exit 1

# imageunzip is not in PATH on faraday (it is meant to run on the nodes)
imageunzip=${IMAGEUNZIP:-/root/r2lab-misc/frisbee-binaries-inria/imageunzip}
[ -x "$imageunzip" ] || { echo "imageunzip not found at $imageunzip: set IMAGEUNZIP"; exit 1; }
echo "using $imageunzip"

status=0
for ndz in "$@"; do
    if [ ! -f "$ndz" ]; then echo "$ndz: no such file"; status=1; continue; fi
    out=$outdir/$(basename "$ndz" .ndz).raw
    echo "=== $ndz -> $out"
    rm -f "$out"
    # -f : output to a regular file; no -z so unallocated areas stay sparse
    if "$imageunzip" -f "$ndz" "$out"; then
        du -h "$out" | sed 's/^/allocated: /'
    else
        echo "$ndz: imageunzip failed"; status=1
    fi
done
exit $status
