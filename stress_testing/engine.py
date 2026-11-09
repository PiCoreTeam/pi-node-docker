"""Bounded asynchronous HTTP load generator and latency metrics."""
from __future__ import annotations

import asyncio
import random
import time
from dataclasses import dataclass, field
from typing import Any

import aiohttp

from .config import Config, Endpoint


@dataclass
class Results:
    started_at: float = field(default_factory=time.time)
    total: int = 0
    successful: int = 0
    failed: int = 0
    status_codes: dict[str, int] = field(default_factory=dict)
    latencies_ms: list[float] = field(default_factory=list)
    latency_total_ms: float = 0.0
    errors: dict[str, int] = field(default_factory=dict)

    def record(self, *, latency_ms: float, status: int | None = None, error: str | None = None) -> None:
        self.total += 1
        self.latency_total_ms += latency_ms
        # Keep percentile samples bounded during long/high-volume runs.
        if len(self.latencies_ms) < 10000:
            self.latencies_ms.append(latency_ms)
        else:
            self.latencies_ms[self.total % 10000] = latency_ms
        if status is not None:
            key = str(status)
            self.status_codes[key] = self.status_codes.get(key, 0) + 1
            if 200 <= status < 400:
                self.successful += 1
            else:
                self.failed += 1
        else:
            self.failed += 1
            name = error or "RequestError"
            self.errors[name] = self.errors.get(name, 0) + 1

    @staticmethod
    def _percentile(values: list[float], percentile: float) -> float:
        if not values:
            return 0.0
        ordered = sorted(values)
        index = min(len(ordered) - 1, max(0, int((len(ordered) - 1) * percentile)))
        return round(ordered[index], 2)

    def summary(self, elapsed_seconds: float) -> dict[str, Any]:
        return {
            "duration_seconds": round(elapsed_seconds, 2),
            "total_requests": self.total,
            "successful_requests": self.successful,
            "failed_requests": self.failed,
            "success_rate_percent": round(self.successful / self.total * 100, 2) if self.total else 0.0,
            "requests_per_second": round(self.total / elapsed_seconds, 2) if elapsed_seconds > 0 else 0.0,
            "latency_ms": {
                "average": round(self.latency_total_ms / self.total, 2) if self.total else 0.0,
                "p50": self._percentile(self.latencies_ms, 0.50),
                "p95": self._percentile(self.latencies_ms, 0.95),
                "p99": self._percentile(self.latencies_ms, 0.99),
            },
            "status_codes": dict(sorted(self.status_codes.items())),
            "errors": dict(sorted(self.errors.items())),
        }


class StressTestEngine:
    def __init__(self, config: Config) -> None:
        self.config = config
        self.results = Results()
        self._stop = asyncio.Event()
        self._started_monotonic: float | None = None
        self._endpoints = [endpoint for endpoint in config.endpoints]
        self._weights = [endpoint.weight for endpoint in self._endpoints]

    def stop(self) -> None:
        self._stop.set()

    def snapshot(self) -> dict[str, Any]:
        """Return a live metrics snapshot for the loopback dashboard."""
        elapsed = max(0.0, time.monotonic() - self._started_monotonic) if self._started_monotonic else 0.0
        return self.results.summary(elapsed)

    async def run(self) -> dict[str, Any]:
        started = time.monotonic()
        self._started_monotonic = started
        deadline = started + self.config.duration
        timeout = aiohttp.ClientTimeout(total=self.config.timeout_seconds)
        connector = aiohttp.TCPConnector(limit=self.config.concurrency, enable_cleanup_closed=True)
        async with aiohttp.ClientSession(timeout=timeout, connector=connector, raise_for_status=False) as session:
            workers = [asyncio.create_task(self._worker(session, index, started, deadline))
                       for index in range(self.config.concurrency)]
            try:
                await asyncio.gather(*workers)
            finally:
                self._stop.set()
                for task in workers:
                    if not task.done():
                        task.cancel()
                await asyncio.gather(*workers, return_exceptions=True)
        elapsed = max(0.0, time.monotonic() - started)
        return self.results.summary(elapsed)

    async def _worker(self, session: aiohttp.ClientSession, index: int, started: float, deadline: float) -> None:
        if self.config.ramp_up_seconds:
            delay = self.config.ramp_up_seconds * index / max(1, self.config.concurrency)
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=delay)
                return
            except asyncio.TimeoutError:
                pass
        while not self._stop.is_set() and time.monotonic() < deadline:
            endpoint: Endpoint = random.choices(self._endpoints, weights=self._weights, k=1)[0]
            url = f"{self.config.base_url}{endpoint.path}"
            request_started = time.perf_counter()
            try:
                async with session.request(endpoint.method, url) as response:
                    await response.content.read(65536)
                    self.results.record(latency_ms=(time.perf_counter() - request_started) * 1000,
                                        status=response.status)
            except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
                self.results.record(latency_ms=(time.perf_counter() - request_started) * 1000,
                                    error=type(exc).__name__)
            except asyncio.CancelledError:
                raise
            if self.config.request_interval:
                try:
                    await asyncio.wait_for(self._stop.wait(), timeout=self.config.request_interval)
                    return
                except asyncio.TimeoutError:
                    pass
