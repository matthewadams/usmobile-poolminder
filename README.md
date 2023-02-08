# US Mobile Data Pool Minder

Tops up a US Mobile if it falls below a given threshold.

Inspired by https://github.com/dbrand666/usmobile-lifeguard

## Intended usage

You can use this script ad-hoc, but it's really intended to be run on a cron-like schedule.

The schedule you pick is up to you.
This script simply does the work to top up a single pool if required.

## Usage

See `./poolminder.sh --help` for usage.

Common usage:

```shell
./poolminder.sh --token "$POOLMINDER_TOKEN" --pool-id "$POOLMINDER_TOKEN" --no-dry-run
```

Sample customized usage:

```shell
./poolminder.sh \
  --token "$POOLMINDER_TOKEN" \
  --pool-id "$POOLMINDER_TOKEN" \
  --no-dry-run \
  --threshold-gb 5 \
  --topup-gb 2
```

> NOTE: In the above example, if your current data remaining in the pool plus the topup meets or exceeds the threshold,
> then the number of gigabytes purchased will be the given value. However, if the the data remaining the pool does not
> meet the threshold, then enough whole gigabytes are added to meet or just exceed the threshold.
