"""
Retry Management System
Handles retry logic with configurable policies
"""

import asyncio
import logging
from typing import Callable, Any, Dict
from dataclasses import dataclass


@dataclass
class RetryPolicy:
    """Configuration for retry behavior"""
    max_retries: int = 5
    base_delay: float = 2.0
    max_delay: float = 60.0
    exponential_backoff: bool = True
    jitter: bool = True


class RetryManager:
    """Manages retry logic for failed operations"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.policy = RetryPolicy(
            max_retries=config.get('max_retries', 5),
            base_delay=config.get('retry_delay', 2.0),
            exponential_backoff=config.get('exponential_backoff', True)
        )
    
    async def execute_with_retry(
        self, 
        func: Callable, 
        *args, 
        **kwargs
    ):
        """
        Execute a function with retry logic
        Returns the result of the function or raises the last exception
        """
        last_exception = None
        
        for attempt in range(self.policy.max_retries):
            try:
                result = await func(*args, **kwargs)
                return result
                
            except Exception as e:
                last_exception = e
                self.logger.warning(
                    f"Attempt {attempt + 1}/{self.policy.max_retries} failed: {e}"
                )
                
                if attempt < self.policy.max_retries - 1:
                    delay = self._calculate_delay(attempt)
                    await asyncio.sleep(delay)
        
        # All retries exhausted
        if last_exception:
            raise last_exception
    
    def _calculate_delay(self, attempt: int) -> float:
        """Calculate delay before next retry"""
        if self.policy.exponential_backoff:
            delay = min(
                self.policy.base_delay * (2 ** attempt),
                self.policy.max_delay
            )
        else:
            delay = self.policy.base_delay
        
        # Add jitter if enabled
        if self.policy.jitter:
            import random
            delay *= (0.5 + random.random())
        
        return delay