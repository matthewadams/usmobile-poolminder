#!/usr/bin/env bash
set -e

for it in bc http jq; do
  if [ -z "$(which $it)" ]; then
    echo "$it required to be on path" >&2
    exit 1
  fi
done

# begin defaults
TOKEN="$POOLMINDER_TOKEN"
POOL_ID="$POOLMINDER_POOL_ID"

THRESHOLD_GB=${POOLMINDER_THRESHOLD_GB:-1}
TOPUP_GB=${POOLMINDER_TOPUP_GB:-1}
AUTH_HEADER=${POOLMINDER_AUTH_HEADER:-USMAuthorization}
TOPUP_SHORTFALL_STRATEGY=${POOLMINDER_TOPUP_SHORTFALL_STRATEGY:-fail}

DRY_RUN=1
# Because a blank DRY_RUN means to **not** do a dry run,
# we need to see if the variable is present in the env,
# then take its value if it is.
if env | grep -Eq '^POOLMINDER_DRY_RUN='; then
  DRY_RUN="$POOLMINDER_DRY_RUN"
fi
# end defaults

function usage() {
  printf "Usage: %s\n
  --token <token> REQUIRED: Your usmobile.com API token.\n\
    It's the JWT returned by (POST /web-gateway/api/v1/auth).\n\
    Use your browser's dev tools to get it.\n\
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
    the behavior is controlled by the strategy given by --topup-shortfall-strategy.\n\
  --topup-shortfall-strategy <'fail' | 'exit' | 'retain' | 'increase'> OPTIONAL, default 'fail':\n\
    the strategy to employ when the topup-gb does not achieve a balance greater than threshold-gb.\n\
    Possible strategies are:\n\
      'fail': the script terminates immediately with a nonzero exit code\n\
      'exit': the script terminates immediately with a exit code of 0\n\
      'retain': the current topup-gb value is retained and applied\n\
      'increase': the current topup-gb value is increased to the next whole gb that meets or exceeds the threshold-gb value\n\
  --verbose OPTIONAL: be verbose.\n\
  --help,-h OPTIONAL: produces this message.\n\
  \n\
  Any unrecognized option will cause this script to exit with a nonzero status.\n\
  \n\
  Also, any option except verbose & help can be set via environment variable.  Prefix is POOLMINDER_, then append option \n\
  converted to UPPER_SNAKE_CASE.  For example, POOLMINDER_THRESHOLD_GB=2 or, to really do it, POOLMINDER_DRY_RUN=''. \n\
  \n\
  Command-line arguments win if both environment variables and command-line arguments are given.\n\
  " \
  "$0"
}

while [ -n "$1" ]; do
  case "$1" in
  --token)
    shift
    TOKEN="$1"
    ;;
  --pool-id)
    shift
    POOL_ID="$1"
    ;;
  --dry-run)
    DRY_RUN=1
    ;;
  --no-dry-run)
    DRY_RUN=
    ;;
  --verbose)
    VERBOSE=1
    ;;
  --no-verbose)
    VERBOSE=
    ;;
  --topup-shortfall-strategy)
    shift
    TOPUP_SHORTFALL_STRATEGY="$1"
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
DRY_RUN="$(echo "$DRY_RUN" | xargs)"
VERBOSE="$(echo "$VERBOSE" | xargs)"
THRESHOLD_GB="$(echo "$THRESHOLD_GB" | xargs)"
TOPUP_GB="$(echo "$TOPUP_GB" | xargs)"
TOPUP_GB="${TOPUP_GB%%.*}" # truncate fraction
TOPUP_SHORTFALL_STRATEGY="$(echo "$TOPUP_SHORTFALL_STRATEGY" | tr '[:upper:]' '[:lower:]' | xargs)"

if [ -n "$VERBOSE" ]; then
  echo "TOKEN=<masked>"
  for it in POOL_ID DRY_RUN THRESHOLD_GB TOPUP_GB ALLOW_TOPUP_INCREASE; do
    echo "$it=${!it}"
  done
fi

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
case "$TOPUP_SHORTFALL_STRATEGY" in
fail | exit | retain | increase) ;;
*)
  echo "invalid topup-shortfall-strategy: $TOPUP_SHORTFALL_STRATEGY" >&2
  exit 3
  ;;
esac

if [ -n "$VERBOSE" ]; then
  echo "TOPUP_GB after truncation=$TOPUP_GB"
fi

AUTH="$AUTH_HEADER:Bearer $TOKEN"
BASE_URL=https://api.usmobile.com/web-gateway/api/v1
POOL_DATA_URL="$BASE_URL/pools/$POOL_ID"
if [ -n "$VERBOSE" ]; then
  echo "POOL_DATA_URL=$POOL_DATA_URL"
fi

json="$(http $POOL_DATA_URL "$AUTH")"
REMAINING_MB="$(echo "$json" | jq .balanceInMB)"
if [ "$REMAINING_MB" == 'null' ]; then
  set -e
  echo "failed to get pool data; response: $(echo "$json" | jq)"
  exit 4
fi

REMAINING_GB="$(echo "$REMAINING_MB / 1024" | bc --mathlib)"
if [ -n "$VERBOSE" ]; then
  echo "REMAINING_MB=$REMAINING_MB"
  echo "REMAINING_GB=$REMAINING_GB"
fi
if [ "$(echo "$REMAINING_GB > $THRESHOLD_GB" | bc --mathlib)" == 1 ]; then
  echo "remaining gb of $REMAINING_GB Gb > $THRESHOLD_GB Gb; not topping up"
  exit 0
fi

# double check TOPUP_GB
if [ "$(echo "$REMAINING_GB + $TOPUP_GB < $THRESHOLD_GB" | bc --mathlib)" == 1 ]; then
  TOPUP_SHORTFALL_GB="$(echo "$THRESHOLD_GB - ($REMAINING_GB + $TOPUP_GB)" | bc --mathlib)"
  if [ -n "$VERBOSE" ]; then
    echo "TOPUP_GB short of threshold by $TOPUP_SHORTFALL_GB"
  fi
  case "$TOPUP_SHORTFALL_STRATEGY" in
  fail)
    echo "topup shortfall of $TOPUP_SHORTFALL_GB; failing based on strategy $TOPUP_SHORTFALL_STRATEGY" >&2
    exit 4
    ;;
  exit)
    echo "topup shortfall of $TOPUP_SHORTFALL_GB; exiting based on strategy $TOPUP_SHORTFALL_STRATEGY"
    exit 0
    ;;
  retain)
    echo "topup shortfall of $TOPUP_SHORTFALL_GB; topping up by only $TOPUP_GB based on strategy $TOPUP_SHORTFALL_STRATEGY"
    ;;
  increase)
    # round up to the next whole gb
    TOPUP_GB="${TOPUP_SHORTFALL_GB%%.*}"              # floor
    TOPUP_GB="$(echo "$TOPUP_GB + 1" | bc --mathlib)" # +1
    echo "topup shortfall of $TOPUP_SHORTFALL_GB; increasing topup to $TOPUP_GB based on strategy $TOPUP_SHORTFALL_STRATEGY"
    ;;
  *)
    echo "unsupported topup strategy $TOPUP_SHORTFALL_STRATEGY" >&2
    exit 4
    ;;
  esac

  if [ -n "$VERBOSE" ]; then
    echo "final TOPUP_GB=$TOPUP_GB"
  fi
fi

TOPUP_URL="$POOL_DATA_URL/topUpAndBasePlan"
CREDIT_CARD_TOKEN="$(echo "$json" | jq -r .creditCardToken)"

if [ -n "$VERBOSE" ]; then
  echo "TOPUP_URL=$TOPUP_URL"
  echo "CREDIT_CARD_TOKEN=$CREDIT_CARD_TOKEN"
fi

if [ -n "$DRY_RUN" ]; then
  echo "dry run -- would issue request:"
  echo "http $TOPUP_URL '$AUTH_HEADER:<masked>' creditCardToken='$CREDIT_CARD_TOKEN' topUpSizeInGB='$TOPUP_GB'"
  exit 0
fi

json="$(http "$TOPUP_URL" "$AUTH" creditCardToken="$CREDIT_CARD_TOKEN" topUpSizeInGB="$TOPUP_GB")"

REMAINING_MB="$(echo "$json" | jq .balanceInMB)"
REMAINING_GB="$(echo "$REMAINING_MB / 1024" | bc --mathlib)"

echo "data now remaining: $REMAINING_GB Gb"
