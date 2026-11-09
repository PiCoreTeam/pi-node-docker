"""Validated configuration loading for the stress-testing tool."""
from __future__ import annotations

import ipaddress
import math
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse
from typing import Any

import yaml


@dataclass(frozen=True)
class Endpoint:
    path: str
    method: str
    weight: float


@dataclass(frozen=True)
class Config:
    base_url: str
    duration: int
    concurrency: int
    ramp_up_seconds: int
    request_interval: float
    timeout_seconds: float
    endpoints: tuple[Endpoint, ...]


def _is_loopback(host: str) -> bool:
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def load_config(path: str | Path, *, allow_external_target: bool = False) -> Config:
    """Load YAML and reject unsafe or nonsensical load-test settings."""
    config_path = Path(path)
    with config_path.open("r", encoding="utf-8") as handle:
        raw: Any = yaml.safe_load(handle)
    if not isinstance(raw, dict):
        raise ValueError("Configuration root must be a YAML mapping")

    target = raw.get("target", {})
    if not isinstance(target, dict):
        raise ValueError("'target' must be a mapping")
    base_url = str(target.get("base_url", "")).rstrip("/")
    parsed = urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("target.base_url must be an absolute http(s) URL")
    if parsed.username or parsed.password:
        raise ValueError("Do not place credentials in target.base_url")
    if not allow_external_target and not _is_loopback(parsed.hostname):
        raise ValueError("External targets are blocked; pass --allow-external-target only when authorized")

    load = raw.get("load", {})
    if not isinstance(load, dict):
        raise ValueError("'load' must be a mapping")
    duration = int(load.get("duration_seconds", 30))
    concurrency = int(load.get("concurrency", 5))
    ramp = int(load.get("ramp_up_seconds", 0))
    interval = float(load.get("request_interval_seconds", 0.1))
    timeout = float(load.get("timeout_seconds", 10))
    if not 1 <= duration <= 86400:
        raise ValueError("load.duration_seconds must be between 1 and 86400")
    if not 1 <= concurrency <= 500:
        raise ValueError("load.concurrency must be between 1 and 500")
    if not 0 <= ramp <= duration:
        raise ValueError("load.ramp_up_seconds must be between 0 and duration_seconds")
    if interval < 0 or timeout <= 0:
        raise ValueError("request interval must be >= 0 and timeout must be > 0")

    endpoint_rows = raw.get("endpoints", [])
    if not isinstance(endpoint_rows, list) or not endpoint_rows:
        raise ValueError("At least one endpoint is required")
    endpoints: list[Endpoint] = []
    for row in endpoint_rows:
        if not isinstance(row, dict):
            raise ValueError("Each endpoint must be a mapping")
        route = str(row.get("path", ""))
        method = str(row.get("method", "GET")).upper()
        weight = float(row.get("weight", 1))
        if not route.startswith("/") or route.startswith("//"):
            raise ValueError("Endpoint paths must begin with one '/'")
        if method not in {"GET", "HEAD"}:
            raise ValueError("Only GET and HEAD are enabled; do not use this tool for state-changing requests")
        if not math.isfinite(weight) or weight <= 0:
            raise ValueError("Endpoint weights must be finite and positive")
        endpoints.append(Endpoint(route, method, weight))

    return Config(base_url, duration, concurrency, ramp, interval, timeout, tuple(endpoints))
