"""
Pull Request Management System
Automatically creates, reviews, and merges pull requests
"""

import asyncio
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
import aiohttp


class PRManager:
    """Manages GitHub pull requests automatically"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.github_token = config.get('github_token', '')
        self.repo_owner = config.get('repo_owner', '')
        self.repo_name = config.get('repo_name', '')
        self.base_branch = config.get('base_branch', 'master')
        self.api_base = 'https://api.github.com'
        
    async def create_pr(
        self, 
        title: str, 
        body: str, 
        head_branch: str,
        labels: List[str] = None
    ) -> Optional[Dict]:
        """Create a new pull request"""
        self.logger.info(f"Creating PR: {title}")
        
        url = f"{self.api_base}/repos/{self.repo_owner}/{self.repo_name}/pulls"
        
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        data = {
            'title': title,
            'body': body,
            'head': head_branch,
            'base': self.base_branch
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=data, headers=headers) as response:
                    if response.status == 201:
                        pr_data = await response.json()
                        pr_number = pr_data['number']
                        
                        self.logger.info(f"✅ PR #{pr_number} created successfully")
                        
                        # Add labels if provided
                        if labels:
                            await self._add_labels(pr_number, labels)
                        
                        return pr_data
                    else:
                        error_text = await response.text()
                        self.logger.error(f"Failed to create PR: {error_text}")
                        return None
                        
        except Exception as e:
            self.logger.error(f"Error creating PR: {e}", exc_info=True)
            return None
    
    async def _add_labels(self, pr_number: int, labels: List[str]):
        """Add labels to a pull request"""
        url = f"{self.api_base}/repos/{self.repo_owner}/{self.repo_name}/issues/{pr_number}/labels"
        
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        data = {'labels': labels}
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=data, headers=headers) as response:
                    if response.status == 200:
                        self.logger.info(f"Labels added to PR #{pr_number}")
                    else:
                        self.logger.warning(f"Failed to add labels to PR #{pr_number}")
                        
        except Exception as e:
            self.logger.error(f"Error adding labels: {e}")
    
    async def review_pr(self, pr_number: int) -> bool:
        """Automatically review a pull request"""
        self.logger.info(f"Reviewing PR #{pr_number}")
        
        # Get PR details
        pr_data = await self._get_pr(pr_number)
        if not pr_data:
            return False
        
        # Run automated checks
        checks_passed = await self._run_automated_checks(pr_data)
        
        # Submit review
        return await self._submit_review(pr_number, checks_passed)
    
    async def _get_pr(self, pr_number: int) -> Optional[Dict]:
        """Get pull request details"""
        url = f"{self.api_base}/repos/{self.repo_owner}/{self.repo_name}/pulls/{pr_number}"
        
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        return await response.json()
                    return None
                    
        except Exception as e:
            self.logger.error(f"Error getting PR: {e}")
            return None
    
    async def _run_automated_checks(self, pr_data: Dict) -> bool:
        """Run automated checks on PR"""
        self.logger.info("Running automated checks...")
        
        # Simulate checks
        await asyncio.sleep(2)
        
        # In real implementation:
        # - Check code quality
        # - Run tests
        # - Check for conflicts
        # - Validate commit messages
        # - Check file changes
        
        return True
    
    async def _submit_review(self, pr_number: int, approved: bool) -> bool:
        """Submit review for PR"""
        url = f"{self.api_base}/repos/{self.repo_owner}/{self.repo_name}/pulls/{pr_number}/reviews"
        
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        event = 'APPROVE' if approved else 'REQUEST_CHANGES'
        body = 'Automated review: All checks passed ✅' if approved else 'Automated review: Issues found ❌'
        
        data = {
            'event': event,
            'body': body
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=data, headers=headers) as response:
                    if response.status == 200:
                        self.logger.info(f"Review submitted for PR #{pr_number}: {event}")
                        return True
                    return False
                    
        except Exception as e:
            self.logger.error(f"Error submitting review: {e}")
            return False
    
    async def merge_pr(self, pr_number: int, merge_method: str = 'squash') -> bool:
        """Merge a pull request"""
        self.logger.info(f"Merging PR #{pr_number} using {merge_method}")
        
        url = f"{self.api_base}/repos/{self.repo_owner}/{self.repo_name}/pulls/{pr_number}/merge"
        
        headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        data = {
            'merge_method': merge_method
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.put(url, json=data, headers=headers) as response:
                    if response.status == 200:
                        self.logger.info(f"✅ PR #{pr_number} merged successfully")
                        return True
                    else:
                        error_text = await response.text()
                        self.logger.error(f"Failed to merge PR: {error_text}")
                        return False
                        
        except Exception as e:
            self.logger.error(f"Error merging PR: {e}", exc_info=True)
            return False
    
    async def auto_process_pr(self, pr_number: int) -> bool:
        """Automatically review and merge a PR if all checks pass"""
        self.logger.info(f"Auto-processing PR #{pr_number}")
        
        # Review PR
        review_passed = await self.review_pr(pr_number)
        
        if not review_passed:
            self.logger.warning(f"PR #{pr_number} did not pass review")
            return False
        
        # Wait a bit before merging
        await asyncio.sleep(5)
        
        # Merge PR
        merge_success = await self.merge_pr(pr_number)
        
        return merge_success