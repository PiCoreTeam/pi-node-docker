"""
Stress Testing Engine
Handles load generation and test execution
"""

import asyncio
import time
from typing import Dict, List, Any
from dataclasses import dataclass, field
import aiohttp
import logging


@dataclass
class StressTestResult:
    """Container for stress test results"""
    start_time: float
    end_time: float
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    average_response_time: float = 0.0
    errors: List[Exception] = field(default_factory=list)
    
    def has_errors(self) -> bool:
        return len(self.errors) > 0
    
    def success_rate(self) -> float:
        if self.total_requests == 0:
            return 0.0
        return (self.successful_requests / self.total_requests) * 100


class StressTestEngine:
    """Executes stress tests with configurable load patterns"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.session: Optional[aiohttp.ClientSession] = None
        self.running = False
        
    async def run_test(self) -> StressTestResult:
        """Execute a stress test cycle"""
        start_time = time.time()
        result = StressTestResult(start_time=start_time, end_time=0)
        
        # Initialize session if needed
        if not self.session:
            self.session = aiohttp.ClientSession()
        
        # Get test configuration
        max_concurrent = self.config.get('max_concurrent_users', 100)
        endpoints = self.config.get('endpoints', [])
        
        # Create tasks for concurrent requests
        tasks = []
        for i in range(max_concurrent):
            endpoint = self._select_endpoint(endpoints, i)
            task = asyncio.create_task(self._execute_request(endpoint, result))
            tasks.append(task)
        
        # Wait for all requests to complete
        await asyncio.gather(*tasks, return_exceptions=True)
        
        result.end_time = time.time()
        result.average_response_time = self._calculate_avg_response_time(result)
        
        self.logger.info(
            f"Stress test completed: {result.successful_requests}/{result.total_requests} successful "
            f"({result.success_rate():.2f}%)"
        )
        
        return result
    
    def _select_endpoint(self, endpoints: List[Dict], index: int) -> Dict:
        """Select endpoint based on weight distribution"""
        if not endpoints:
            return {'path': '/', 'method': 'GET'}
        
        # Simple round-robin for now (can be enhanced with weighted selection)
        return endpoints[index % len(endpoints)]
    
    async def _execute_request(self, endpoint: Dict, result: StressTestResult):
        """Execute a single HTTP request"""
        result.total_requests += 1
        
        try:
            method = endpoint.get('method', 'GET')
            path = endpoint.get('path', '/')
            url = f"{self.config.get('base_url', 'http://localhost')}{path}"
            
            async with self.session.request(method, url, timeout=aiohttp.ClientTimeout(total=30)) as response:
                await response.read()
                
                if 200 <= response.status < 300:
                    result.successful_requests += 1
                else:
                    result.failed_requests += 1
                    
        except Exception as e:
            result.failed_requests += 1
            result.errors.append(e)
            self.logger.debug(f"Request failed: {e}")
    
    def _calculate_avg_response_time(self, result: StressTestResult) -> float:
        """Calculate average response time"""
        if result.total_requests == 0:
            return 0.0
        
        duration = result.end_time - result.start_time
        return duration / result.total_requests
    
    async def stop(self):
        """Stop the stress test engine"""
        self.running = False
        if self.session:
            await self.session.close()
        self.logger.info("Stress test engine stopped")