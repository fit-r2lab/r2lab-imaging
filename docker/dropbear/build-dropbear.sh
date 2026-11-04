#!/bin/bash
# Build a statically linked dropbear, to be injected by 'rhubarbe docker load'
# in containers whose image has no sshd. Needs docker on the build machine,
# which must have the same architecture as the testbed nodes.
#
# usage: build-dropbear.sh [output-file]      (default: ./dropbear)
# then point [docker] dropbear in rhubarbe.conf to the result
#
# NOT YET TESTED - check that the result is static: `file dropbear`

set -e
VERSION=${DROPBEAR_VERSION:-2025.88}
OUT=$(realpath "${1:-./dropbear}")
DIR=$(dirname "$OUT")

docker run --rm -v "$DIR:/out" -e VERSION="$VERSION" -e NAME="$(basename "$OUT")" \
    alpine:3 sh -ec '
  apk add --no-cache build-base curl bzip2
  curl -fsSL https://matt.ucc.asn.au/dropbear/releases/dropbear-$VERSION.tar.bz2 \
    | tar xj
  cd dropbear-$VERSION
  ./configure --enable-static --disable-zlib --disable-pam \
      --disable-lastlog --disable-utmp --disable-wtmp --disable-wtmpx
  make PROGRAMS=dropbear
  strip dropbear
  cp dropbear /out/$NAME
'
file "$OUT" 2>/dev/null || true
