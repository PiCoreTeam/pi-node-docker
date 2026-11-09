# Isolated HTTP Stress Testing Utility

This utility is an optional developer tool. It is not part of the Pi Node container startup path and does not modify stellar-core, Horizon, PostgreSQL, node configuration, or persistent node data.

## Safety defaults

- Only HTTP `GET` and `HEAD` requests are accepted.
- Targets must resolve syntactically to loopback (`localhost` or a loopback IP) unless the operator explicitly passes `--allow-external-target`.
- Concurrency is bounded to 1–500 workers; test duration is bounded to 24 hours.
- The example config targets `127.0.0.1` and uses a read-only `/health` endpoint.
- The tool does not attempt to restart services, change memory limits, refresh credentials, or merge pull requests.

External testing must be authorized by the target owner. Start with low concurrency and increase gradually. Never point a load test at Pi Network production infrastructure without explicit written authorization.

## Install and run

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-stress-testing.txt
python -m pip install -e .  # optional if using the package entry point
python -m stress_testing.cli --config config/stress-test.example.yaml
```

The package can also be invoked with `python -m stress_testing.cli` without an editable install. The example expects a local service listening on port 8000 with a `/health` endpoint.

To open the optional live dashboard during a test:

```bash
python -m stress_testing.cli --config config/stress-test.example.yaml --dashboard
```

The dashboard binds only to `127.0.0.1` (default port `8080`) and reads the same live counters used in the final report. It has no wildcard CORS, external scripts, or public bind option. Open `http://127.0.0.1:8080/` on the machine running the test.

To save a JSON report:

```bash
python -m stress_testing.cli --config config/stress-test.example.yaml --output results.json
```

Only after confirming authorization for a non-local target, add `--allow-external-target`.

## Configuration

- `target.base_url`: local HTTP(S) origin, without credentials.
- `load.duration_seconds`: 1–86400 seconds.
- `load.concurrency`: 1–500 concurrent workers.
- `load.ramp_up_seconds`: 0 through the configured duration.
- `load.request_interval_seconds`: pause between each worker's requests.
- `load.timeout_seconds`: per-request timeout.
- `endpoints`: weighted paths; only GET and HEAD are permitted.

## Validation

Run the isolated test suite with:

```bash
python -m pip install -r requirements-stress-testing.txt
python -m compileall -q stress_testing
python -m unittest discover -s tests -p 'test_stress_testing.py' -v
```

The CI workflow runs these checks on Python 3.11 and 3.12. This utility is deliberately independent of the Docker image build and node runtime.
