"""
System Constants
Centralized constants used across the system
"""

# Version
VERSION = "1.0.0"
SYSTEM_NAME = "Intelligent Stress Testing System"

# Error Categories
ERROR_CATEGORY_CRITICAL = "critical"
ERROR_CATEGORY_RECOVERABLE = "recoverable"
ERROR_CATEGORY_IGNORABLE = "ignorable"
ERROR_CATEGORY_WARNING = "warning"

# Error Actions
ERROR_ACTION_ALERT_AND_RETRY = "alert_and_retry"
ERROR_ACTION_AUTO_RETRY = "auto_retry"
ERROR_ACTION_LOG_ONLY = "log_only"
ERROR_ACTION_ESCALATE = "escalate"

# Recovery Strategies
STRATEGY_GENERIC_RETRY = "generic_retry"
STRATEGY_EXPONENTIAL_BACKOFF = "exponential_backoff"
STRATEGY_RECONNECT = "reconnect_with_backoff"
STRATEGY_RATE_LIMIT = "rate_limit_backoff"
STRATEGY_RESTART = "restart_with_increased_memory"
STRATEGY_REFRESH_CREDENTIALS = "refresh_credentials"
STRATEGY_LOG_CONTINUE = "log_and_continue"

# Default Configuration Values
DEFAULT_MAX_RETRIES = 5
DEFAULT_RETRY_DELAY = 2.0
DEFAULT_MAX_CONCURRENT = 100
DEFAULT_TEST_DURATION = 3600
DEFAULT_METRICS_INTERVAL = 10
DEFAULT_DASHBOARD_PORT = 8080

# HTTP Status Codes
HTTP_OK = 200
HTTP_CREATED = 201
HTTP_BAD_REQUEST = 400
HTTP_UNAUTHORIZED = 401
HTTP_FORBIDDEN = 403
HTTP_NOT_FOUND = 404
HTTP_RATE_LIMIT = 429
HTTP_SERVER_ERROR = 500

# Metrics Thresholds
ERROR_RATE_WARNING_THRESHOLD = 5.0  # percentage
ERROR_RATE_CRITICAL_THRESHOLD = 10.0  # percentage
LOAD_WARNING_THRESHOLD = 70.0  # percentage
LOAD_CRITICAL_THRESHOLD = 90.0  # percentage

# Time Constants
SECOND = 1
MINUTE = 60
HOUR = 3600
DAY = 86400

# Storage Paths
DEFAULT_LOGS_DIR = "logs"
DEFAULT_DATA_DIR = "data"
DEFAULT_CONFIG_DIR = "config"

# GitHub PR Settings
PR_LABEL_AUTOMATED = "automated"
PR_LABEL_STRESS_TEST = "stress-test"
PR_LABEL_ERROR_FIX = "error-fix"

# Dashboard Settings
DASHBOARD_UPDATE_INTERVAL = 2  # seconds
METRICS_HISTORY_LIMIT = 1000
METRICS_DISPLAY_LIMIT = 100