"""
Network Simulation and Monitoring
Simulates network conditions and monitors network statistics
"""

import asyncio
import logging
import psutil
import time
from typing import Dict, Any
from dataclasses import dataclass


@dataclass
class NetworkStats:
    """Network statistics container"""
    bytes_sent: int
    bytes_recv: int
    packets_sent: int
    packets_recv: int
    errin: int
    errout: int
    dropin: int
    dropout: int
    timestamp: float


class NetworkSimulator:
    """Network simulation and monitoring system"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.enabled = config.get('enabled', True)
        self.latency_ms = config.get('latency_ms', 0)
        self.packet_loss = config.get('packet_loss', 0.0)
        self.bandwidth_limit = config.get('bandwidth_limit_mbps', 0)
        
    async def get_network_stats(self) -> Dict[str, Any]:
        """Get current network statistics"""
        try:
            # Get network I/O statistics
            net_io = psutil.net_io_counters()
            
            stats = NetworkStats(
                bytes_sent=net_io.bytes_sent,
                bytes_recv=net_io.bytes_recv,
                packets_sent=net_io.packets_sent,
                packets_recv=net_io.packets_recv,
                errin=net_io.errin,
                errout=net_io.errout,
                dropin=net_io.dropin,
                dropout=net_io.dropout,
                timestamp=time.time()
            )
            
            # Calculate load percentage
            load = self._calculate_load(stats)
            
            return {
                'bytes_sent': stats.bytes_sent,
                'bytes_recv': stats.bytes_recv,
                'packets_sent': stats.packets_sent,
                'packets_recv': stats.packets_recv,
                'errors': stats.errin + stats.errout,
                'drops': stats.dropin + stats.dropout,
                'load': load,
                'timestamp': stats.timestamp
            }
            
        except Exception as e:
            self.logger.error(f"Error getting network stats: {e}")
            return {
                'load': 0.0,
                'errors': 0,
                'timestamp': time.time()
            }
    
    def _calculate_load(self, stats: NetworkStats) -> float:
        """Calculate network load percentage"""
        # Simple load calculation based on packet rate
        # In real implementation, this would be more sophisticated
        
        if hasattr(self, '_last_stats'):
            time_delta = stats.timestamp - self._last_stats.timestamp
            if time_delta > 0:
                packets_per_sec = (
                    (stats.packets_sent - self._last_stats.packets_sent) +
                    (stats.packets_recv - self._last_stats.packets_recv)
                ) / time_delta
                
                # Assume max capacity of 10000 packets/sec
                load = min((packets_per_sec / 10000) * 100, 100)
            else:
                load = 0.0
        else:
            load = 0.0
        
        self._last_stats = stats
        return load
    
    async def simulate_latency(self, duration_ms: int = None):
        """Simulate network latency"""
        if not self.enabled:
            return
        
        latency = duration_ms if duration_ms else self.latency_ms
        if latency > 0:
            await asyncio.sleep(latency / 1000)
    
    async def simulate_packet_loss(self) -> bool:
        """
        Simulate packet loss
        Returns True if packet should be dropped
        """
        if not self.enabled or self.packet_loss <= 0:
            return False
        
        import random
        return random.random() < (self.packet_loss / 100)
    
    def get_system_info(self) -> Dict[str, Any]:
        """Get system information"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            return {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'memory_available_gb': memory.available / (1024**3),
                'disk_percent': disk.percent,
                'disk_free_gb': disk.free / (1024**3)
            }
        except Exception as e:
            self.logger.error(f"Error getting system info: {e}")
            return {}