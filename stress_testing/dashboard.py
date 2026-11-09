"""Loopback-only live metrics dashboard; no CORS or external asset dependencies."""
from __future__ import annotations

from aiohttp import web

from .engine import StressTestEngine


_INDEX = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pi Node Stress Test — Live Metrics</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#101827;color:#e5edf7}body{max-width:1000px;margin:40px auto;padding:0 20px}
header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.muted{color:#9aabc1}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin:28px 0}
article{background:#1a2940;border:1px solid #31435d;border-radius:12px;padding:18px}article h2{font-size:13px;font-weight:600;color:#9aabc1;margin:0 0 12px}article p{font-size:28px;font-weight:700;margin:0;overflow-wrap:anywhere}
pre{background:#1a2940;border:1px solid #31435d;border-radius:12px;padding:16px;overflow:auto}footer{margin-top:24px;color:#9aabc1;font-size:13px}
</style></head><body>
<header><div><h1>Pi Node Stress Test</h1><p class="muted">Live local metrics · refreshes every 1 second</p></div><strong id="connection">Connecting…</strong></header>
<section class="grid">
<article><h2>Total requests</h2><p id="total">0</p></article><article><h2>Successful</h2><p id="successful">0</p></article>
<article><h2>Failed</h2><p id="failed">0</p></article><article><h2>Requests / second</h2><p id="rps">0</p></article>
<article><h2>Average latency</h2><p id="average">0 ms</p></article><article><h2>p95 latency</h2><p id="p95">0 ms</p></article>
<article><h2>Success rate</h2><p id="rate">0%</p></article><article><h2>Elapsed</h2><p id="duration">0 s</p></article>
</section><h2>HTTP status codes</h2><pre id="statuses">No requests yet</pre><h2>Errors</h2><pre id="errors">None</pre>
<footer>Bound to 127.0.0.1 only. No authentication or cross-origin access is enabled; do not expose this port publicly.</footer>
<script>
async function refresh(){try{const r=await fetch('/api/metrics',{cache:'no-store'});if(!r.ok)throw new Error('HTTP '+r.status);const m=await r.json();
const put=(id,v)=>document.getElementById(id).textContent=v;
put('total',m.total_requests);put('successful',m.successful_requests);put('failed',m.failed_requests);put('rps',m.requests_per_second);
put('average',m.latency_ms.average+' ms');put('p95',m.latency_ms.p95+' ms');put('rate',m.success_rate_percent+'%');put('duration',m.duration_seconds+' s');
put('statuses',JSON.stringify(m.status_codes,null,2));put('errors',JSON.stringify(m.errors,null,2)||'None');put('connection','● Live');
}catch(e){document.getElementById('connection').textContent='● Disconnected';}}
refresh();setInterval(refresh,1000);
</script></body></html>"""


def create_app(engine: StressTestEngine) -> web.Application:
    app = web.Application()

    async def index(_: web.Request) -> web.Response:
        return web.Response(text=_INDEX, content_type="text/html", headers={"Cache-Control": "no-store"})

    async def metrics(_: web.Request) -> web.Response:
        return web.json_response(engine.snapshot(), headers={"Cache-Control": "no-store"})

    app.router.add_get("/", index)
    app.router.add_get("/api/metrics", metrics)
    return app


class DashboardServer:
    """Serve metrics on loopback only; the bind address is intentionally fixed."""

    def __init__(self, engine: StressTestEngine, *, port: int = 8080) -> None:
        if not 1024 <= port <= 65535:
            raise ValueError("Dashboard port must be between 1024 and 65535")
        self.app = create_app(engine)
        self.port = port
        self.runner: web.AppRunner | None = None

    async def start(self) -> None:
        self.runner = web.AppRunner(self.app, access_log=None)
        await self.runner.setup()
        site = web.TCPSite(self.runner, host="127.0.0.1", port=self.port)
        await site.start()

    async def stop(self) -> None:
        if self.runner is not None:
            await self.runner.cleanup()
            self.runner = None
