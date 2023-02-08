#!/usr/bin/env bash
set -e

for it in bc http jq; do
  if [ -z "$(which $it)" ]; then
    echo "$it required to be on path" >&2
    exit 1
  fi
done

# defaults
DRY_RUN=1
THRESHOLD_GB=1
TOPUP_GB=1
TOKEN="$POOLMINDER_TOKEN"
POOL_ID="$POOLMINDER_POOL_ID"

function usage() {
  printf "Usage: $0\n
  --token <token> REQUIRED: Your usmobile.com API token.\n\
    It's the JWT returned by (POST /web-gateway/api/v1/auth).\n\
    It can also be specified via environment variable POOLMINDER_TOKEN.\n\
  --pool-id <pool-id> REQUIRED: The id of the data pool you want to possibly top up.\n\
    Go to https://app.usmobile.com/dashboard/app/pools,\n\
    click on the pool you want, then get the id from the last token in the address bar.\n\
    It can also be specified via environment variable POOLMINDER_POOL_ID.\n\
  --dry-run OPTIONAL, default is as though this flag were present.\n\
  --no-dry-run OPTIONAL: specify this flag if you want to actually have the script top up the data pool, spending your money.\n\
  --threshold-gb <threshold> OPTIONAL, default 1: the minimum number of gigabytes remaining before a topup is performed.\n\
  --topup-gb <topup> OPTIONAL, default 1: the number of gigabytes to top up the pool with.\n\
    Any fraction will be truncated.\n\
    If the pool's current balance plus this value doesn't achieve the threshold,\n\
    it is increased to be the next whole number of gigabytes that meets or exceeds the threshold.\n\
  --help,-h OPTIONAL: produces this message.\n\
  \n\
  Any unrecognized option will cause this script to exit with a nonzero status.\n"
}

while [ -n "$1" ]; do
  case "$1" in
  # required args
  --token)
    shift
    TOKEN="$1"
    ;;
  --pool-id)
    shift
    POOL_ID="$1"
    ;;
  # optional args
  --dry-run)
    DRY_RUN=1
    ;;
  --no-dry-run)
    DRY_RUN=
    ;;
  --threshold-gb)
    shift
    THRESHOLD_GB="$1"
    ;;
  --topup-gb)
    shift
    TOPUP_GB="$1"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown option: $1"
    usage >&2
    exit 2
    ;;
  esac
  shift
done

# scrub
TOKEN="$(echo "$TOKEN" | xargs)"
POOL_ID="$(echo "$POOL_ID" | xargs)"
AUTH_HEADER="$(echo "$AUTH_HEADER" | xargs)"
DRY_RUN="$(echo "$DRY_RUN" | xargs)"

# validate
if [ -z "$TOKEN" ]; then
  echo "token required" >&2
  exit 3
fi
if [ -z "$POOL_ID" ]; then
  echo "pool-id required" >&2
  exit 3
fi
if [ "$(echo "$THRESHOLD_GB <= 0" | bc --mathlib)" == 1 ]; then
  echo "threshold-gb must be >= 0" >&2
  exit 3
fi
if [ "$(echo "$TOPUP_GB <= 0" | bc)" == 1 ]; then
  echo "topup-gb must be >= 0" >&2
  exit 3
fi

TOPUP_GB="$(printf '%.0f' "$TOPUP_GB")" # truncate fraction
BASE_URL=https://api.usmobile.com/web-gateway/api/v1

AUTH="USMAuthorization:Bearer $TOKEN"
POOL_DATA_URL="$BASE_URL/pools/$POOL_ID"

json="$(http $POOL_DATA_URL "$AUTH")"
REMAINING_MB="$(echo "$json" | jq .balanceInMB)"
REMAINING_GB="$(echo "$REMAINING_MB / 1024" | bc --mathlib)"
if [ "$(echo "$REMAINING_GB > $THRESHOLD_GB" | bc --mathlib)" == 1 ]; then
  echo "remaining gb of $REMAINING_GB Gb > $THRESHOLD_GB Gb; not topping up"
  exit 0
fi

# double check TOPUP_GB
if [ "$(echo "$REMAINING_GB + $TOPUP_GB < $THRESHOLD_GB" | bc --mathlib)" == 1 ]; then
  TOPUP_GB="$(echo "$THRESHOLD_GB - $REMAINING_GB" | bc --mathlib)"
  # now round up to the next whole gb
  TOPUP_GB="$(printf '%.0f' $TOPUP_GB)" # floor
  TOPUP_GB="$(echo "$TOPUP_GB + 1" | bc --mathlib)"
fi

TOPUP_URL="$POOL_DATA_URL/topUpAndBasePlan"
CREDIT_CARD_TOKEN="$(echo "$json" | jq -r .creditCardToken)"

cmd="http $TOPUP_URL '$AUTH' creditCardToken='$CREDIT_CARD_TOKEN' topUpSizeInGB='$TOPUP_GB'"
if [ -n "$DRY_RUN" ]; then
  echo "dry run -- would issue request: $cmd"
  exit 0
fi

json="$(http "$TOPUP_URL" "$AUTH" creditCardToken="$CREDIT_CARD_TOKEN" topUpSizeInGB="$TOPUP_GB")"

REMAINING_MB="$(echo "$json" | jq .balanceInMB)"
REMAINING_GB="$(echo "$REMAINING_MB / 1024" | bc --mathlib)"

echo "data now remaining: $REMAINING_GB Gb"
