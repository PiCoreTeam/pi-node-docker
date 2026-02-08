"""
Dashboard API Server
Provides RESTful API for dashboard frontend
"""

import asyncio
import logging
from typing import Dict, Any
from aiohttp import web



class DashboardAPI:
    """RESTful API server for dashboard"""
    
    def __init__(self, metrics_collector, config: Dict[str, Any]):
        self.metrics_collector = metrics_collector
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.app = web.Application()
        self._setup_routes()
        
    def _setup_routes(self):
        """Setup API routes"""
        self.app.router.add_get('/api/metrics/current', self.get_current_metrics)
        self.app.router.add_get('/api/metrics/history', self.get_metrics_history)
        self.app.router.add_get('/api/health', self.health_check)
        self.app.router.add_get('/', self.serve_dashboard)
        
        # Enable CORS
        self.app.middlewares.append(self._cors_middleware)
    
    @web.middleware
    async def _cors_middleware(self, request, handler):
        """CORS middleware with basic preflight handling and restricted origins."""
        origin = request.headers.get('Origin')

        # Allow overriding CORS origins via config; default to localhost-only.
        allowed_origins = self.config.get(
            'allowed_origins',
            ['http://localhost', 'http://127.0.0.1']
        )

        # Handle preflight OPTIONS requests directly to avoid 405s on handlers.
        if request.method == 'OPTIONS':
            response = web.Response(status=204)
        else:
            response = await handler(request)

        # Set CORS headers only for allowed origins.
        if origin and origin in allowed_origins:
            response.headers['Access-Control-Allow-Origin'] = origin
            # Ensure caches vary on Origin when CORS is applied.
            existing_vary = response.headers.get('Vary')
            if existing_vary:
                if 'Origin' not in existing_vary:
                    response.headers['Vary'] = existing_vary + ', Origin'
            else:
                response.headers['Vary'] = 'Origin'

        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        response.headers['Access-Control-Max-Age'] = '3600'
        return response
    
    async def get_current_metrics(self, request):
        """Get current metrics"""
        try:
            metrics = self.metrics_collector.get_current_metrics()
            return web.json_response(metrics)
        except Exception as e:
            self.logger.error(f"Error getting current metrics: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def get_metrics_history(self, request):
        """Get metrics history"""
        try:
            limit = int(request.query.get('limit', 100))
            history = self.metrics_collector.get_metrics_history(limit)
            return web.json_response({'history': history})
        except Exception as e:
            self.logger.error(f"Error getting metrics history: {e}")
            return web.json_response({'error': str(e)}, status=500)
    
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({'status': 'healthy', 'timestamp': asyncio.get_event_loop().time()})
    
    async def serve_dashboard(self, request):
        """Serve dashboard HTML"""
        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Stress Testing Dashboard</title>
            <meta charset="utf-8">
        </head>
        <body>
            <h1>Stress Testing Dashboard</h1>
            <p>API is running. Use /api/metrics/current to get metrics.</p>
        </body>
        </html>
        """
        return web.Response(text=html, content_type='text/html')
    
    async def start(self):
        """Start the API server"""
        port = self.config.get('port', 8080)
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', port)
        await site.start()
        self.logger.info(f"Dashboard API started on port {port}")