"""
Common Utility Functions
Shared utility functions used across the system
"""

import yaml
import json
import os
from pathlib import Path
from typing import Dict, Any
import hashlib
import time


def load_config(config_path: str) -> Dict[str, Any]:
    """
    Load configuration from YAML file
    
    Args:
        config_path: Path to configuration file
        
    Returns:
        Configuration dictionary
    """
    config_file = Path(config_path)
    
    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_file, 'r') as f:
        if config_path.endswith('.yaml') or config_path.endswith('.yml'):
            config = yaml.safe_load(f)
        elif config_path.endswith('.json'):
            config = json.load(f)
        else:
            raise ValueError(f"Unsupported configuration file format: {config_path}")
    
    # Environment variable substitution
    config = substitute_env_vars(config)
    
    return config


def substitute_env_vars(data: Any) -> Any:
    """
    Recursively substitute environment variables in configuration
    Format: ${VAR_NAME} or ${VAR_NAME:default_value}
    """
    if isinstance(data, dict):
        return {k: substitute_env_vars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [substitute_env_vars(item) for item in data]
    elif isinstance(data, str):
        if data.startswith('${') and data.endswith('}'):
            var_expr = data[2:-1]
            if ':' in var_expr:
                var_name, default = var_expr.split(':', 1)
                return os.getenv(var_name, default)
            else:
                return os.getenv(var_expr, data)
    return data


def save_json(data: Dict[str, Any], filepath: str, pretty: bool = True):
    """Save data to JSON file"""
    Path(filepath).parent.mkdir(parents=True, exist_ok=True)
    
    with open(filepath, 'w') as f:
        if pretty:
            json.dump(data, f, indent=2)
        else:
            json.dump(data, f)


def load_json(filepath: str) -> Dict[str, Any]:
    """Load data from JSON file"""
    with open(filepath, 'r') as f:
        return json.load(f)


def calculate_hash(data: str, algorithm: str = 'sha256') -> str:
    """Calculate hash of string data"""
    hasher = hashlib.new(algorithm)
    hasher.update(data.encode('utf-8'))
    return hasher.hexdigest()


def format_bytes(bytes_value: int) -> str:
    """Format bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.2f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.2f} PB"


def format_duration(seconds: float) -> str:
    """Format duration in seconds to human readable format"""
    if seconds < 60:
        return f"{seconds:.2f}s"
    elif seconds < 3600:
        minutes = seconds / 60
        return f"{minutes:.2f}m"
    elif seconds < 86400:
        hours = seconds / 3600
        return f"{hours:.2f}h"
    else:
        days = seconds / 86400
        return f"{days:.2f}d"


def ensure_directory(path: str):
    """Ensure directory exists"""
    Path(path).mkdir(parents=True, exist_ok=True)


def timestamp_to_iso(timestamp: float) -> str:
    """Convert Unix timestamp to ISO format string"""
    from datetime import datetime
    return datetime.fromtimestamp(timestamp).isoformat()


class Timer:
    """Context manager for timing operations"""
    
    def __init__(self, name: str = "Operation"):
        self.name = name
        self.start_time = None
        self.duration = None
    
    def __enter__(self):
        self.start_time = time.time()
        return self
    
    def __exit__(self, *args):
        self.duration = time.time() - self.start_time
        print(f"{self.name} took {format_duration(self.duration)}")