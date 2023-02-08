# US Mobile Data Pool Minder

Tops up a US Mobile if it is below a given threshold.

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
> meet the threshold, you need to tell the script what do to.

If your `topup-gb` is not enough to get you at or over `threshold-gb`, the script will fail, unless you provide a strategy via
the `--topup-shortfall-strategy`. Allowed values are:

* `fail` (the default): causes the script to fail with a nonzero exit code.
* `exit`: causes the script to do nothing and terminate with a zero exit code.
* `retain`: leaves the `topup-gb` value unchanged and performs a topup, leaving you below `threshold-gb`, but not
  costing you any more then you expect.
* `increase`: increases `topup-gb` to the next whole gigabyte that, when added to your data pool balance, meets or
  exceeds `threshold-gb`. This will cost you more money, obviously, so use it with care.

## Docker

You can build your own Docker image with this repo's `Dockerfile`, until such time as I get images publishing
automatically
to https://hub.docker.com. Usage is the same as the raw script usage. For example:

```shell
docker build -t poolminder:latest .
docker run --rm -it poolminder:latest --token "$POOLMINDER_TOKEN" --pool-id "$POOLMINDER_TOKEN" --no-dry-run
```
