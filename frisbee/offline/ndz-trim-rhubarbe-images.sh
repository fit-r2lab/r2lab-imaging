#!/bin/bash
# Trim images of the rhubarbe repository, end to end, with all files in the current directory.
# Run on faraday, as root.
#
# usage: sudo ndz-trim-rhubarbe-images.sh [--rm-raw] radical [radical ...]
#
# for each radical (e.g. ubuntu, fedora; anything `rhubarbe resolve` understands):
#   1. rhubarbe resolve   -> the actual .ndz in the repository (its basename is kept)
#   2. ndz-extract.sh     -> ./<base>.raw
#   3. ndz-trim.sh        -> ./<base>-trimmed.raw
#   4. ndz-rewrap.sh      -> ./<base>-trimmed.ndz
# --rm-raw removes the two .raw files once the new .ndz is there (each is several G).
# The environment knobs of ndz-trim.sh (PURGE_SNAPD, KEEP_KERNEL, ...) are passed through.
# The repository is only read, never written to.

here=$(cd "$(dirname "$0")" && pwd)
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

rmraw=
while [ $# -gt 0 ]; do
    case $1 in
        --rm-raw) rmraw=1; shift;;
        -h|--help) usage;;
        --) shift; break;;
        -*) echo "unknown option $1"; usage;;
        *) break;;
    esac
done
[ $# -gt 0 ] || usage
[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }
command -v rhubarbe >/dev/null || { echo "rhubarbe not found in PATH"; exit 1; }

# 1. resolve everything first, so that a typo is spotted before any long operation
bases=(); ndzs=(); status=0
for radical in "$@"; do
    # we only trust what is an actual file: take the last word of the last line of the output
    path=$(rhubarbe resolve "$radical" 2>/dev/null | tail -1 | awk '{print $NF}')
    if [ -f "$path" ] && [[ $path == *.ndz ]]; then
        echo "$radical -> $path"
        bases+=("$(basename "$path" .ndz)"); ndzs+=("$path")
    else
        echo "$radical: cannot resolve to an .ndz file (got '$path'), skipped"; status=1
    fi
done
[ ${#bases[@]} -gt 0 ] || exit 1

# 2-4. one image at a time, to bound the disk usage
results=()
for i in "${!bases[@]}"; do
    base=${bases[$i]}; ndz=${ndzs[$i]}
    echo; echo "################################################################ $base"
    if "$here/ndz-extract.sh" -o . "$ndz" \
       && "$here/ndz-trim.sh" -o . "./$base.raw" \
       && "$here/ndz-rewrap.sh" -f -o . "./$base-trimmed.raw" \
       && [ -f "./$base-trimmed.ndz" ]; then
        results+=("$base $(stat -c %s "$ndz") $(stat -c %s "./$base-trimmed.ndz")")
        [ -n "$rmraw" ] && rm -f "./$base.raw" "./$base-trimmed.raw"
    else
        echo "$base: FAILED, see messages above"; results+=("$base - -"); status=1
    fi
done

echo; echo "=============== summary (.ndz sizes in MB)"
printf '%-30s %10s %10s %8s\n' image original trimmed saved
for r in "${results[@]}"; do
    read -r name o t <<< "$r"
    if [ "$o" = - ]; then printf '%-30s %10s\n' "$name" FAILED
    else printf '%-30s %10s %10s %8s\n' "$name" $((o >> 20)) $((t >> 20)) $(((o - t) >> 20)); fi
done
exit $status
