#!/bin/bash
set -eo pipefail

if [ -z "$USER_PASSWORD" ] || [ "$USER_PASSWORD" = "random_see_log"; then
  echo >&2 'USER_PASSWORD not specified, generating random password.'
  USER_PASSWORD=$(date +%s | sha256sum | base64 | head -c 20 ; echo)
  echo >2& '*******************************************************'
  echo >&2 'Password set to: ' $USER_PASSWORD
  echo >2& '*******************************************************'

  #exit 1
fi

if [ "$USER_NAME" ]; then
  # username specifically provided, will overwrite 'mc'
  if [[ "$USER_NAME" =~ [^a-zA-Z0-9] ]]; then
    echo >&2 'USER_NAME must contain only alphanumerics [a-zA-Z0-9]'
    exit 1
  fi
else
  echo >&2 'USER_NAME not provided; defaulting to "mc"'
  USER_NAME=mc
fi

if [ "$USER_UID" ]; then
  # uid specifically provided, will overwrite 1000 default
  if [[ "$USER_UID" =~ [^0-9] ]]; then
    echo >&2 'USER_UID must contain only numerics [0-9]'
    exit 1
  fi
else
  USER_UID=1000
fi

if id -u $USER_NAME >/dev/null 2>&1; then
  echo "$USER_NAME already exists."
else
  useradd -Ms /bin/false -u $USER_UID $USER_NAME
  echo "$USER_NAME:$USER_PASSWORD" | chpasswd
  echo >&2 "Created user: $USER_NAME (uid: $USER_UID)"
fi

if [ ! -z "$USE_HTTPS" ]; then
  # update mineos.conf from environment
  sed -i 's/use_https = .*/use_https = '${USE_HTTPS}'/g' /etc/mineos.conf
  echo >&2 "Setting use_https to: " $USE_HTTPS
  if [[ -z $SERVER_PORT ]] && [ "$USE_HTTPS" = "true"  ]; then
    Port=8443
  elif [[ -z $SERVER_PORT ]] && [ "$USE_HTTPS" = "false"  ]; then
    Port=8080
  else
    Port=$SERVER_PORT
  fi
  sed -i 's/socket_port = .*/socket_port = '${Port}'/g' /etc/mineos.conf
  echo >&2 "Setting server port to: "$Port
fi

if [[ ! -f /etc/ssl/certs/mineos.crt ]] && [[ ! -z $( grep 'use_https = true' /etc/mineos.conf) ]]; then
  # generate the cert if it is missing and enabled in the config
  echo >&2 "Generating Self-Signed SSL..."
  sh /usr/games/minecraft/generate-sslcert.sh
else
  echo >&2 "Skipping Self-Signed SSL, it either exists or is disabled."
fi

exec "$@"
