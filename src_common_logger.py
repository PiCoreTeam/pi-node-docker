"""
Logging Configuration
Centralized logging setup for all components
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from typing import Dict, Any


def setup_logging(config: Dict[str, Any] = None) -> logging.Logger:
    """
    Setup centralized logging configuration
    
    Args:
        config: Logging configuration dictionary
        
    Returns:
        Configured logger instance
    """
    if config is None:
        config = {}
    
    # Get configuration values
    log_level = config.get('level', 'INFO')
    log_file = config.get('file', 'logs/stress_testing.log')
    log_format = config.get(
        'format',
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    max_bytes = config.get('max_bytes', 10 * 1024 * 1024)  # 10MB
    backup_count = config.get('backup_count', 5)
    
    # Create logs directory if it doesn't exist
    log_path = Path(log_file)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Create formatter
    formatter = logging.Formatter(log_format)
    
    # Setup root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))
    
    # Remove existing handlers
    root_logger.handlers = []
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level.upper()))
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=max_bytes,
        backupCount=backup_count
    )
    file_handler.setLevel(getattr(logging, log_level.upper()))
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    
    # Create application logger
    logger = logging.getLogger('stress_testing_system')
    logger.info("Logging system initialized")
    
    return logger


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance for a specific module"""
    return logging.getLogger(f'stress_testing_system.{name}')