"""
Metrics Collection System
Collects, aggregates, and stores system metrics
"""


import logging
import time
from typing import Dict, Any, List
from dataclasses import dataclass, asdict
from datetime import datetime
import json


@dataclass
class SystemMetrics:
    """Container for system metrics"""
    timestamp: float
    error_rate: float = 0.0
    stress_load: float = 0.0
    bypassed_errors: int = 0
    fixed_errors: int = 0
    manual_intervention_count: int = 0
    success_rate: float = 100.0
    uptime: float = 0.0
    active_recovery_processes: int = 0
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0


class MetricsCollector:
    """Collects and manages system metrics"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.metrics = SystemMetrics(timestamp=time.time())
        self.metrics_history: List[SystemMetrics] = []
        self.start_time = time.time()
        self.storage_path = config.get('storage_path', 'data/metrics.json')
        
    async def record_test_results(self, results):
        """Record stress test results"""
        self.metrics.total_requests += results.total_requests
        self.metrics.successful_requests += results.successful_requests
        self.metrics.failed_requests += results.failed_requests
        
        # Calculate error rate
        if self.metrics.total_requests > 0:
            self.metrics.error_rate = (
                self.metrics.failed_requests / self.metrics.total_requests
            ) * 100
            
            self.metrics.success_rate = (
                self.metrics.successful_requests / self.metrics.total_requests
            ) * 100
        
        self.logger.debug(f"Recorded test results: {results.total_requests} requests")
    
    async def record_error(self, classification):
        """Record an error classification"""

        self.logger.debug(f"Recorded error: {classification.error_type}")
    
    async def record_critical_error(self, exception: Exception):
        """Record a critical error"""
        self.logger.critical(f"Critical error recorded: {exception}")
    
    async def increment_active_recovery(self):
        """Increment active recovery process count"""
        self.metrics.active_recovery_processes += 1
    
    async def decrement_active_recovery(self):
        """Decrement active recovery process count"""
        self.metrics.active_recovery_processes = max(
            0, 
            self.metrics.active_recovery_processes - 1
        )
    
    async def increment_fixed_errors(self):
        """Increment fixed errors count"""
        self.metrics.fixed_errors += 1
        self.logger.info(f"Fixed errors count: {self.metrics.fixed_errors}")
    
    async def increment_bypassed_errors(self):
        """Increment bypassed errors count"""
        self.metrics.bypassed_errors += 1
        self.logger.info(f"Bypassed errors count: {self.metrics.bypassed_errors}")
    
    async def increment_manual_intervention_count(self):
        """Increment manual intervention count"""
        self.metrics.manual_intervention_count += 1
        self.logger.warning(
            f"Manual intervention count: {self.metrics.manual_intervention_count}"
        )
    
    async def record_system_metrics(self, metrics: Dict[str, Any]):
        """Record system-level metrics"""
        self.metrics.stress_load = metrics.get('load', 0.0)
        self.metrics.uptime = time.time() - self.start_time
        
    async def aggregate_and_store(self):
        """Aggregate and store metrics"""
        # Update timestamp
        self.metrics.timestamp = time.time()
        
        # Add to history
        self.metrics_history.append(SystemMetrics(**asdict(self.metrics)))
        
        # Keep only last 1000 entries
        if len(self.metrics_history) > 1000:
            self.metrics_history = self.metrics_history[-1000:]
        
        # Store to file
        await self._save_metrics()
        
        self.logger.debug("Metrics aggregated and stored")
    
    async def _save_metrics(self):
        """Save metrics to storage"""
        try:

            # In real implementation, save to database or file
            # For now, just log
            self.logger.debug(f"Metrics saved: {len(self.metrics_history)} entries")
            
        except Exception as e:
            self.logger.error(f"Error saving metrics: {e}")
    
    def get_current_metrics(self) -> Dict[str, Any]:
        """Get current metrics as dictionary"""
        return asdict(self.metrics)
    
    def get_metrics_history(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get metrics history"""
        return [asdict(m) for m in self.metrics_history[-limit:]]
    
    async def close(self):
        """Close metrics collector"""
        await self._save_metrics()
        self.logger.info("Metrics collector closed")