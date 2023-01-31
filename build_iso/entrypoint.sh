#!/bin/sh

set -e

log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# ipv6
if [ ! -f "/proc/net/if_inet6" ]; then
    log "$ME: info: ipv6 not available"
    exit 0
fi

if [ ! -f "/$DEFAULT_CONF_FILE" ]; then
    log "$ME: info: /$DEFAULT_CONF_FILE is not a file or does not exist"
    exit 0
fi

# check if the file can be modified, e.g. not on a r/o filesystem
touch /"$DEFAULT_CONF_FILE" 2>/dev/null || {
  log "$ME: info: can not modify /$DEFAULT_CONF_FILE (read-only file system?)"; exit 0;
}

# check if the file is already modified, e.g. on a container restart
grep -q "listen  \[::]\:80;" /"$DEFAULT_CONF_FILE" && {
  log "$ME: info: IPv6 listen already enabled"; exit 0;
}

if [ -f "/etc/os-release" ]; then
    . /etc/os-release
else
    log "$ME: info: can not guess the operating system"
    exit 0
fi

log "$ME: info: Getting the checksum of /$DEFAULT_CONF_FILE"

case "$ID" in
    "debian")
        CHECKSUM=$(dpkg-query --show --showformat='${Conffiles}\n' nginx | grep "$DEFAULT_CONF_FILE" | cut -d' ' -f 3)
        echo "$CHECKSUM  /$DEFAULT_CONF_FILE" | md5sum -c - >/dev/null 2>&1 || {
            log "$ME: info: /$DEFAULT_CONF_FILE differs from the packaged version"
            exit 0
        }
        ;;
    "alpine")
        CHECKSUM=$(apk manifest nginx 2>/dev/null| grep "$DEFAULT_CONF_FILE" | cut -d' ' -f 1 | cut -d ':' -f 2)
        echo "$CHECKSUM  /$DEFAULT_CONF_FILE" | sha1sum -c - >/dev/null 2>&1 || {
            log "$ME: info: /$DEFAULT_CONF_FILE differs from the packaged version"
            exit 0
        }
        ;;
    *)
        log "$ME: info: Unsupported distribution"
        exit 0
        ;;
esac

# enable ipv6 on default.conf listen sockets
sed -i -E 's,listen       80;,listen       80;\n    listen  [::]:80;,' /"$DEFAULT_CONF_FILE"
log "$ME: info: Enabled listen on IPv6 in /$DEFAULT_CONF_FILE"

exit 0

