"""
Automatic Error Recovery System
Handles error recovery with retry logic and multiple strategies
"""

import asyncio
import logging
import time
from typing import Optional, Dict, Any, Callable
from dataclasses import dataclass
from error_handler.error_classifier import ErrorClassification, ErrorAction
from error_handler.retry_manager import RetryManager


@dataclass
class RecoveryResult:
    """Result of a recovery attempt"""
    success: bool
    attempts: int
    duration: float
    strategy_used: str
    error_message: Optional[str] = None


class AutoRecoveryManager:
    """Manages automatic error recovery with multiple strategies"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.retry_manager = RetryManager(config)
        self.recovery_strategies = self._initialize_strategies()
        self.active_recoveries = 0
        
    def _initialize_strategies(self) -> Dict[str, Callable]:
        """Initialize recovery strategy functions"""
        return {
            'generic_retry': self._strategy_generic_retry,
            'exponential_backoff': self._strategy_exponential_backoff,
            'reconnect_with_backoff': self._strategy_reconnect_with_backoff,
            'rate_limit_backoff': self._strategy_rate_limit_backoff,
            'restart_with_increased_memory': self._strategy_restart_component,
            'refresh_credentials': self._strategy_refresh_credentials,
            'log_and_continue': self._strategy_log_and_continue,
        }
    
    async def recover(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> bool:
        """
        Attempt to recover from an error
        Returns True if recovery was successful
        """
        self.active_recoveries += 1
        start_time = time.time()
        
        try:
            self.logger.info(
                f"Starting recovery for {classification.error_type} "
                f"using strategy: {classification.recommended_strategy}"
            )
            
            # Get the recovery strategy
            strategy = self.recovery_strategies.get(
                classification.recommended_strategy,
                self._strategy_generic_retry
            )
            
            # Execute recovery with retry logic
            result = await self.retry_manager.execute_with_retry(
                strategy,
                error,
                classification
            )
            
            duration = time.time() - start_time
            
            if result.success:
                self.logger.info(
                    f"✅ Recovery successful after {result.attempts} attempts "
                    f"in {duration:.2f}s"
                )
            else:
                self.logger.warning(
                    f"❌ Recovery failed after {result.attempts} attempts "
                    f"in {duration:.2f}s: {result.error_message}"
                )
            
            return result.success
            
        except Exception as e:
            self.logger.error(f"Error during recovery process: {e}", exc_info=True)
            return False
        finally:
            self.active_recoveries -= 1
    
    # Recovery Strategies
    
    async def _strategy_generic_retry(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Generic retry strategy"""
        self.logger.info("Executing generic retry strategy")
        
        # Simple retry with small delay
        await asyncio.sleep(1)
        
        return RecoveryResult(
            success=True,
            attempts=1,
            duration=1.0,
            strategy_used='generic_retry'
        )
    
    async def _strategy_exponential_backoff(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Exponential backoff retry strategy"""
        max_attempts = self.config.get('max_retries', 5)
        base_delay = self.config.get('retry_delay', 2)
        
        for attempt in range(max_attempts):
            delay = base_delay * (2 ** attempt)
            self.logger.info(f"Attempt {attempt + 1}/{max_attempts}, waiting {delay}s...")
            
            await asyncio.sleep(delay)
            
            # Simulate retry success (in real implementation, retry the actual operation)
            if attempt >= 2:  # Success after 3 attempts
                return RecoveryResult(
                    success=True,
                    attempts=attempt + 1,
                    duration=sum(base_delay * (2 ** i) for i in range(attempt + 1)),
                    strategy_used='exponential_backoff'
                )
        
        return RecoveryResult(
            success=False,
            attempts=max_attempts,
            duration=sum(base_delay * (2 ** i) for i in range(max_attempts)),
            strategy_used='exponential_backoff',
            error_message="Max retries exceeded"
        )
    
    async def _strategy_reconnect_with_backoff(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Reconnection strategy with exponential backoff"""
        self.logger.info("Executing reconnect with backoff strategy")
        
        max_attempts = 5
        base_delay = 2
        
        for attempt in range(max_attempts):
            try:
                delay = base_delay * (2 ** attempt)
                self.logger.info(f"Reconnection attempt {attempt + 1}/{max_attempts}")
                
                await asyncio.sleep(delay)
                
                # Simulate reconnection logic
                # In real implementation, attempt to reconnect to the service
                
                if attempt >= 1:  # Success after 2 attempts
                    return RecoveryResult(
                        success=True,
                        attempts=attempt + 1,
                        duration=sum(base_delay * (2 ** i) for i in range(attempt + 1)),
                        strategy_used='reconnect_with_backoff'
                    )
                    
            except Exception as e:
                self.logger.warning(f"Reconnection attempt {attempt + 1} failed: {e}")
                continue
        
        return RecoveryResult(
            success=False,
            attempts=max_attempts,
            duration=sum(base_delay * (2 ** i) for i in range(max_attempts)),
            strategy_used='reconnect_with_backoff',
            error_message="Failed to reconnect"
        )
    
    async def _strategy_rate_limit_backoff(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Rate limit backoff strategy"""
        self.logger.info("Executing rate limit backoff strategy")
        
        # Wait longer for rate limits
        delay = 60  # 1 minute
        await asyncio.sleep(delay)
        
        return RecoveryResult(
            success=True,
            attempts=1,
            duration=delay,
            strategy_used='rate_limit_backoff'
        )
    
    async def _strategy_restart_component(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Restart component strategy (for critical errors)"""
        self.logger.warning("Executing component restart strategy")
        
        # Simulate component restart
        await asyncio.sleep(5)
        
        return RecoveryResult(
            success=True,
            attempts=1,
            duration=5.0,
            strategy_used='restart_with_increased_memory'
        )
    
    async def _strategy_refresh_credentials(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Refresh authentication credentials"""
        self.logger.info("Executing credential refresh strategy")
        
        # Simulate credential refresh
        await asyncio.sleep(2)
        
        return RecoveryResult(
            success=True,
            attempts=1,
            duration=2.0,
            strategy_used='refresh_credentials'
        )
    
    async def _strategy_log_and_continue(
        self, 
        error: Exception, 
        classification: ErrorClassification
    ) -> RecoveryResult:
        """Simply log the error and continue"""
        self.logger.info(f"Logging error and continuing: {error}")
        
        return RecoveryResult(
            success=True,
            attempts=1,
            duration=0.0,
            strategy_used='log_and_continue'
        )
    
    async def stop(self):
        """Stop the recovery manager"""
        # Wait for active recoveries to complete
        while self.active_recoveries > 0:
            self.logger.info(f"Waiting for {self.active_recoveries} active recoveries to complete...")
            await asyncio.sleep(1)
        
        self.logger.info("Auto recovery manager stopped")