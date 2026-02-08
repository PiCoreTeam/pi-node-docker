#!/usr/bin/env python3
"""
Intelligent Stress Testing System - Main Entry Point
Handles continuous stress testing with automatic error recovery
"""

import asyncio
import logging
import signal
import sys
from pathlib import Path
from typing import Optional

import yaml
from stress_engine import StressTestEngine
from network_simulator import NetworkSimulator
from error_handler.error_classifier import ErrorClassifier
from error_handler.auto_recovery import AutoRecoveryManager
from dashboard.backend.metrics_collector import MetricsCollector
from common.logger import setup_logging
from common.utils import load_config


class StressTestingSystem:
    """Main orchestrator for the intelligent stress testing system"""
    
    def __init__(self, config_path: str):
        self.config = load_config(config_path)
        self.logger = setup_logging(self.config.get('logging', {}))
        
        # Initialize components
        self.stress_engine = StressTestEngine(self.config['stress_test'])
        self.network_simulator = NetworkSimulator(self.config.get('network', {}))
        self.error_classifier = ErrorClassifier(self.config['error_handling'])
        self.recovery_manager = AutoRecoveryManager(self.config['error_handling'])
        self.metrics_collector = MetricsCollector(self.config['monitoring'])
        
        self.running = False
        self._setup_signal_handlers()
    
    def _setup_signal_handlers(self):
        """Setup graceful shutdown on SIGINT/SIGTERM"""
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown...")
        self.running = False
    
    async def start(self):
        """Start the stress testing system"""
        self.logger.info("🚀 Starting Intelligent Stress Testing System...")
        self.running = True
        
        # Start all components
        tasks = [
            asyncio.create_task(self._run_stress_tests()),
            asyncio.create_task(self._monitor_system()),
            asyncio.create_task(self._collect_metrics()),
        ]
        
        try:
            await asyncio.gather(*tasks)
        except Exception as e:
            self.logger.error(f"Critical error in main loop: {e}", exc_info=True)
        finally:
            await self.shutdown()
    
    async def _run_stress_tests(self):
        """Main stress testing loop with error recovery"""
        self.logger.info("📊 Starting stress test execution...")
        
        while self.running:
            try:
                # Execute stress test
                results = await self.stress_engine.run_test()
                
                # Collect metrics
                await self.metrics_collector.record_test_results(results)
                
                # Check for errors
                if results.has_errors():
                    await self._handle_errors(results.errors)
                
            except Exception as e:
                self.logger.error(f"Error in stress test loop: {e}")
                # Classify and handle error in background
                await self._handle_exception(e)
                # Continue testing without interruption
                continue
            
            await asyncio.sleep(self.config['stress_test'].get('test_interval', 1))
    
    async def _handle_errors(self, errors: list):
        """Handle errors detected during stress testing"""
        for error in errors:
            # Classify error
            classification = self.error_classifier.classify(error)
            
            self.logger.info(f"Error classified as: {classification.category}")
            
            # Record error metrics
            await self.metrics_collector.record_error(classification)
            
            # Handle based on classification
            if classification.requires_manual_intervention:
                self.logger.warning(f"⚠️ Manual intervention required: {error}")
                await self.metrics_collector.increment_manual_intervention_count()
            else:
                # Start automatic recovery in background
                asyncio.create_task(
                    self._auto_recover(error, classification)
                )
    
    async def _handle_exception(self, exception: Exception):
        """Handle unexpected exceptions"""
        classification = self.error_classifier.classify_exception(exception)
        
        if classification.is_critical:
            self.logger.critical(f"🚨 Critical error: {exception}")
            await self.metrics_collector.record_critical_error(exception)
        else:
            # Attempt automatic recovery
            asyncio.create_task(
                self._auto_recover(exception, classification)
            )
    
    async def _auto_recover(self, error, classification):
        """Attempt automatic error recovery in background"""
        self.logger.info(f"🔧 Starting automatic recovery for: {error}")
        
        try:
            # Increment active recovery processes
            await self.metrics_collector.increment_active_recovery()
            
            # Attempt recovery with retry logic
            success = await self.recovery_manager.recover(error, classification)
            
            if success:
                self.logger.info(f"✅ Successfully recovered from: {error}")
                await self.metrics_collector.increment_fixed_errors()
            else:
                self.logger.warning(f"❌ Failed to recover from: {error}")
                await self.metrics_collector.increment_bypassed_errors()
                
        except Exception as e:
            self.logger.error(f"Error during recovery: {e}")
        finally:
            await self.metrics_collector.decrement_active_recovery()
    
    async def _monitor_system(self):
        """Monitor system health and resources"""
        self.logger.info("🔍 Starting system monitoring...")
        
        while self.running:
            try:
                # Collect system metrics
                metrics = await self.network_simulator.get_network_stats()
                await self.metrics_collector.record_system_metrics(metrics)
                
            except Exception as e:
                self.logger.error(f"Error in monitoring: {e}")
            
            await asyncio.sleep(self.config['monitoring'].get('metrics_interval', 10))
    
    async def _collect_metrics(self):
        """Aggregate and store metrics"""
        self.logger.info("📈 Starting metrics collection...")
        
        while self.running:
            try:
                await self.metrics_collector.aggregate_and_store()
            except Exception as e:
                self.logger.error(f"Error collecting metrics: {e}")
            
            await asyncio.sleep(self.config['monitoring'].get('aggregation_interval', 60))
    
    async def shutdown(self):
        """Graceful shutdown of all components"""
        self.logger.info("🛑 Shutting down Intelligent Stress Testing System...")
        
        # Stop all components
        await self.stress_engine.stop()
        await self.recovery_manager.stop()
        await self.metrics_collector.close()
        
        self.logger.info("✅ Shutdown complete")


async def main():
    """Main entry point"""
    config_path = sys.argv[1] if len(sys.argv) > 1 else 'config/stress_test_config.yaml'
    
    system = StressTestingSystem(config_path)
    await system.start()


if __name__ == '__main__':
    asyncio.run(main())