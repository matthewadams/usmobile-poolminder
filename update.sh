#!/usr/bin/env bash
set -e

APP=poolminder
APP_ARG="-a $APP"
APP_REGEX="^$APP"
TAG="$(cat VERSION)"
SCHEDULE=daily
LOCATION=local
if [ -z "$(which docker)" ]; then
  LOCATION=remote
fi
ARGS="${@:---verbose --no-dry-run --topup-shortfall-strategy increase --threshold-gb 2 --sleep-before-exit 5}"

if [ -z "$(fly apps list | grep -vE '^APP\s+' | grep -iE "$APP_REGEX\s+")" ]; then
  echo "No app named $APP found; creating." >&2
  fly apps create $APP --machines
else
  echo "App $APP exists; not creating." >&2
fi

echo "Building & pushing Docker image ${LOCATION}ly." >&2
fly deploy \
  $APP_ARG \
  --build-only \
  --${LOCATION}-only \
  --push \
  --image-label $TAG \
  --verbose

# just nuke all machines & run a new one
IDS="$(fly machine list -q $APP_ARG)"
if [ -n "$IDS" ]; then
  echo "Existing machine(s) found; destroying." >&2
  for id in $IDS; do
    echo "Destroying machine $id." >&2
    fly machine destroy "$id" $APP_ARG -f --verbose
  done
fi

IMAGE=registry.fly.io/$APP:$TAG
echo "Running $IMAGE on a new machine $SCHEDULE with args $ARGS." >&2
if [ "$SCHEDULE" == once ]; then
  SCHEDULE=
else
  SCHEDULE="--schedule $SCHEDULE"
fi

fly machine run \
  $IMAGE \
  --detach \
  --verbose \
  $APP_ARG \
  $SCHEDULE \
  -- \
  $ARGS

echo "OK" >&2
