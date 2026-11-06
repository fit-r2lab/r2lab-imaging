# offline image trimming

All in one, from an empty working directory (resolves the names with `rhubarbe resolve`,
leaves `X.raw`, `X-trimmed.raw` and `X-trimmed.ndz` in `.`; add `--rm-raw` to drop the raws):

```
PURGE_SNAPD=1 ./ndz-trim-rhubarbe-images.sh ubuntu fedora docker podman
```

Or step by step:

Run on faraday, as root. Use a scratch directory with room for ~8G per image.

```
./ndz-extract.sh -o /tmp /var/lib/rhubarbe-images/{ubuntu,fedora,docker,podman}.ndz   # -> /tmp/X.raw
PURGE_SNAPD=1 ./ndz-trim.sh /tmp/{ubuntu,fedora,docker,podman}.raw                   # -> /tmp/X-trimmed.raw
./ndz-rewrap.sh /tmp/*-trimmed.raw                                                      # -> /tmp/X-trimmed.ndz
ls -lh /var/lib/rhubarbe-images/{ubuntu,fedora,docker,podman}.ndz /tmp/*-trimmed.ndz    # compare sizes
```

`ndz-inspect.sh X.raw` gives a read-only report on any raw image.
