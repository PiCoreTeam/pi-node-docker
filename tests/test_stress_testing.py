import tempfile
import unittest
from pathlib import Path

import yaml

from stress_testing.config import load_config
from stress_testing.engine import Results, StressTestEngine
from stress_testing.config import Config, Endpoint
from aiohttp.test_utils import TestClient, TestServer
from stress_testing.dashboard import create_app


class ConfigTests(unittest.TestCase):
    def write_config(self, data):
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False, encoding="utf-8")
        yaml.safe_dump(data, handle)
        handle.close()
        self.addCleanup(Path(handle.name).unlink, missing_ok=True)
        return handle.name

    def valid_config(self):
        return {
            "target": {"base_url": "http://127.0.0.1:8000"},
            "load": {"duration_seconds": 10, "concurrency": 2},
            "endpoints": [{"path": "/health", "method": "GET", "weight": 1}],
        }

    def test_loads_valid_local_config(self):
        config = load_config(self.write_config(self.valid_config()))
        self.assertEqual(config.concurrency, 2)
        self.assertEqual(config.endpoints[0].path, "/health")

    def test_blocks_external_target_by_default(self):
        data = self.valid_config()
        data["target"]["base_url"] = "https://example.com"
        with self.assertRaisesRegex(ValueError, "External targets are blocked"):
            load_config(self.write_config(data))

    def test_rejects_state_changing_method(self):
        data = self.valid_config()
        data["endpoints"][0]["method"] = "POST"
        with self.assertRaisesRegex(ValueError, "Only GET and HEAD"):
            load_config(self.write_config(data))

    def test_rejects_excessive_concurrency(self):
        data = self.valid_config()
        data["load"]["concurrency"] = 501
        with self.assertRaisesRegex(ValueError, "concurrency"):
            load_config(self.write_config(data))


class MetricsTests(unittest.TestCase):
    def test_counts_statuses_errors_and_percentiles(self):
        result = Results()
        result.record(latency_ms=10, status=200)
        result.record(latency_ms=20, status=503)
        result.record(latency_ms=30, error="TimeoutError")
        summary = result.summary(2)
        self.assertEqual(summary["total_requests"], 3)
        self.assertEqual(summary["successful_requests"], 1)
        self.assertEqual(summary["failed_requests"], 2)
        self.assertEqual(summary["status_codes"]["503"], 1)
        self.assertEqual(summary["errors"]["TimeoutError"], 1)
        self.assertEqual(summary["latency_ms"]["average"], 20)


class DashboardTests(unittest.IsolatedAsyncioTestCase):
    async def test_live_metrics_endpoint_and_local_dashboard(self):
        config = Config("http://127.0.0.1:8000", 10, 1, 0, 0.1, 5, (Endpoint("/health", "GET", 1),))
        engine = StressTestEngine(config)
        engine.results.record(latency_ms=12, status=200)
        client = TestClient(TestServer(create_app(engine)))
        await client.start_server()
        self.addAsyncCleanup(client.close)
        response = await client.get("/api/metrics")
        self.assertEqual(response.status, 200)
        payload = await response.json()
        self.assertEqual(payload["total_requests"], 1)
        page = await client.get("/")
        self.assertEqual(page.status, 200)
        self.assertIn("Pi Node Stress Test", await page.text())
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)


if __name__ == "__main__":
    unittest.main()
