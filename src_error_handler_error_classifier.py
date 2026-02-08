"""
Error Classification System
Automatically categorizes errors and determines handling strategy
"""

import logging
import re
from dataclasses import dataclass
from enum import Enum
from typing import Dict, Any, List


class ErrorCategory(Enum):
    """Error severity categories"""
    CRITICAL = "critical"
    RECOVERABLE = "recoverable"
    IGNORABLE = "ignorable"
    WARNING = "warning"


class ErrorAction(Enum):
    """Actions to take for different error types"""
    ALERT_AND_RETRY = "alert_and_retry"
    AUTO_RETRY = "auto_retry"
    LOG_ONLY = "log_only"
    ESCALATE = "escalate"


@dataclass
class ErrorClassification:
    """Result of error classification"""
    category: ErrorCategory
    action: ErrorAction
    error_type: str
    severity_score: int  # 1-10
    is_critical: bool
    requires_manual_intervention: bool
    recommended_strategy: str
    metadata: Dict[str, Any]


class ErrorClassifier:
    """Intelligent error classification system"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.error_rules = self._load_error_rules()
        self.pattern_cache = {}
        
    def _load_error_rules(self) -> Dict[str, Dict]:
        """Load error handling rules from config"""
        rules = {}
        
        # Critical errors
        for error_type in self.config.get('error_categories', {}).get('critical', []):
            rules[error_type] = {
                'category': ErrorCategory.CRITICAL,
                'action': ErrorAction.ALERT_AND_RETRY,
                'severity': 9,
                'manual_intervention': True
            }
        
        # Recoverable errors
        for error_type in self.config.get('error_categories', {}).get('recoverable', []):
            rules[error_type] = {
                'category': ErrorCategory.RECOVERABLE,
                'action': ErrorAction.AUTO_RETRY,
                'severity': 5,
                'manual_intervention': False
            }
        
        # Ignorable errors
        for error_type in self.config.get('error_categories', {}).get('ignorable', []):
            rules[error_type] = {
                'category': ErrorCategory.IGNORABLE,
                'action': ErrorAction.LOG_ONLY,
                'severity': 2,
                'manual_intervention': False
            }
        
        return rules
    
    def classify(self, error: Exception) -> ErrorClassification:
        """Classify an error and determine handling strategy"""
        error_type = type(error).__name__
        error_message = str(error)
        
        # Check if we have a specific rule for this error type
        if error_type in self.error_rules:
            rule = self.error_rules[error_type]
            return self._create_classification(error_type, error_message, rule)
        
        # Pattern-based classification
        classification = self._classify_by_pattern(error_type, error_message)
        if classification:
            return classification
        
        # Default classification for unknown errors
        return self._create_default_classification(error_type, error_message)
    
    def classify_exception(self, exception: Exception) -> ErrorClassification:
        """Classify an exception (alias for classify)"""
        return self.classify(exception)
    
    def _classify_by_pattern(self, error_type: str, error_message: str) -> ErrorClassification:
        """Classify error based on message patterns"""
        patterns = {
            r'connection.*refused|timeout|timed out': {
                'category': ErrorCategory.RECOVERABLE,
                'action': ErrorAction.AUTO_RETRY,
                'severity': 6,
                'strategy': 'exponential_backoff'
            },
            r'out of memory|oom|memory error': {
                'category': ErrorCategory.CRITICAL,
                'action': ErrorAction.ALERT_AND_RETRY,
                'severity': 10,
                'strategy': 'restart_with_increased_memory'
            },
            r'rate limit|too many requests|429': {
                'category': ErrorCategory.RECOVERABLE,
                'action': ErrorAction.AUTO_RETRY,
                'severity': 4,
                'strategy': 'rate_limit_backoff'
            },
            r'database.*connection|db error|sql': {
                'category': ErrorCategory.CRITICAL,
                'action': ErrorAction.ALERT_AND_RETRY,
                'severity': 8,
                'strategy': 'reconnect_with_backoff'
            },
            r'unauthorized|authentication|forbidden': {
                'category': ErrorCategory.CRITICAL,
                'action': ErrorAction.ESCALATE,
                'severity': 9,
                'strategy': 'refresh_credentials'
            },
            r'not found|404': {
                'category': ErrorCategory.WARNING,
                'action': ErrorAction.LOG_ONLY,
                'severity': 3,
                'strategy': 'log_and_continue'
            }
        }
        
        for pattern, rule in patterns.items():
            if re.search(pattern, error_message, re.IGNORECASE):
                return self._create_classification(
                    error_type, 
                    error_message, 
                    {
                        'category': rule['category'],
                        'action': rule['action'],
                        'severity': rule['severity'],
                        'manual_intervention': rule['severity'] >= 8
                    },
                    recommended_strategy=rule['strategy']
                )
        
        return None
    
    def _create_classification(
        self, 
        error_type: str, 
        error_message: str, 
        rule: Dict,
        recommended_strategy: str = None
    ) -> ErrorClassification:
        """Create an ErrorClassification object"""
        
        # Determine strategy
        if not recommended_strategy:
            strategies = self.config.get('auto_fix_strategies', [])
            for strategy_config in strategies:
                if strategy_config.get('error_type') == error_type:
                    recommended_strategy = strategy_config.get('strategy', 'generic_retry')
                    break
            
            if not recommended_strategy:
                recommended_strategy = 'generic_retry'
        
        return ErrorClassification(
            category=rule['category'],
            action=rule['action'],
            error_type=error_type,
            severity_score=rule['severity'],
            is_critical=rule['severity'] >= 8,
            requires_manual_intervention=rule.get('manual_intervention', False),
            recommended_strategy=recommended_strategy,
            metadata={
                'error_message': error_message,
                'timestamp': logging.Formatter().formatTime(logging.LogRecord(
                    '', 0, '', 0, '', (), None
                ))
            }
        )
    
    def _create_default_classification(
        self, 
        error_type: str, 
        error_message: str
    ) -> ErrorClassification:
        """Create default classification for unknown errors"""
        self.logger.warning(f"Unknown error type: {error_type}, using default classification")
        
        return ErrorClassification(
            category=ErrorCategory.WARNING,
            action=ErrorAction.AUTO_RETRY,
            error_type=error_type,
            severity_score=5,
            is_critical=False,
            requires_manual_intervention=False,
            recommended_strategy='generic_retry',
            metadata={
                'error_message': error_message,
                'is_unknown': True
            }
        )
    
    def get_statistics(self) -> Dict[str, int]:
        """Get classification statistics"""
        return {
            'total_rules': len(self.error_rules),
            'critical_rules': sum(1 for r in self.error_rules.values() 
                                if r['category'] == ErrorCategory.CRITICAL),
            'recoverable_rules': sum(1 for r in self.error_rules.values() 
                                   if r['category'] == ErrorCategory.RECOVERABLE),
        }