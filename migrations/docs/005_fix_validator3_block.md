# Migration 005: Replace 3rd validator block

Replaces the entire 3rd `[[VALIDATORS]]` block in `stellar-core.cfg` with the correct validator3 values.

## Run manually

```bash
bash /migrations/005_fix_validator3_key.sh
```

## Expected result

3rd validator block in `/opt/stellar/core/etc/stellar-core.cfg`:

```toml
[[VALIDATORS]]
NAME="validator3"
HOME_DOMAIN="pi-core-team"
PUBLIC_KEY="GAXTE5AV5OCOEGJE4OPVMN5UJHAKDQCSVMXI4P7SZIGQXVO7LP4JKX4M"
ADDRESS="34.64.252.77:31402"
HISTORY="curl -sf https://history.mainnet.minepi.com/{0} -o {1}"
```
