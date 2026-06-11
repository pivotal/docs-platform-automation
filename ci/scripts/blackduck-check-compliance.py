#!/usr/bin/env python3

import os
import sys
import requests
import json
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def get_env_var(name, required=True):
    value = os.environ.get(name)
    if required and not value:
        logger.error(f"Environment variable {name} is required but not set.")
        sys.exit(1)
    return value

def authenticate(url, token):
    logger.info(f"Authenticating with Black Duck at {url}...")
    auth_url = f"{url}/api/tokens/authenticate"
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.blackducksoftware.user-4+json'
    }
    try:
        response = requests.post(auth_url, headers=headers, timeout=30)
        response.raise_for_status()
        bearer_token = response.json().get('bearerToken')
        logger.info("Successfully authenticated.")
        return bearer_token
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        sys.exit(1)

def get_project_by_name(url, bearer_token, project_name):
    logger.info(f"Searching for project: {project_name}...")
    projects_url = f"{url}/api/projects?q=name:{project_name}"
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Accept': 'application/json'
    }
    try:
        response = requests.get(projects_url, headers=headers, timeout=30)
        response.raise_for_status()
        items = response.json().get('items', [])
        for item in items:
            if item.get('name') == project_name:
                logger.info(f"Found project: {project_name} at {item['_meta']['href']}")
                return item
        logger.error(f"Project '{project_name}' not found.")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Failed to get project: {e}")
        sys.exit(1)

def get_version_by_name(url, bearer_token, project_url, version_name):
    logger.info(f"Searching for version '{version_name}' in project...")
    versions_url = f"{project_url}/versions?q=versionName:{version_name}"
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Accept': 'application/json'
    }
    try:
        response = requests.get(versions_url, headers=headers, timeout=30)
        response.raise_for_status()
        items = response.json().get('items', [])
        for item in items:
            if item.get('versionName') == version_name:
                logger.info(f"Found version: {version_name} at {item['_meta']['href']}")
                return item
        logger.error(f"Version '{version_name}' not found.")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Failed to get version: {e}")
        sys.exit(1)

def check_compliance(url, bearer_token, version_url):
    print("\n" + "="*80)
    print(" STEP: CHECKING COMPONENT COMPLIANCE (USAGE) ".center(80, "="))
    print("="*80)

    # Filter for LICENSE violations
    components_url = f"{version_url}/components?filter=policyCategory:LICENSE&limit=100"
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Accept': 'application/json'
    }

    stats = {
        'total_violating': 0,
        'compliant': 0,
        'missing_usage': 0,
        'non_compliant_list': []
    }

    while components_url:
        try:
            response = requests.get(components_url, headers=headers, timeout=30)
            response.raise_for_status()
            data = response.json()
            items = data.get('items', [])

            for item in items:
                # Only care about components still in violation
                if item.get('policyStatus') != 'IN_VIOLATION':
                    continue

                stats['total_violating'] += 1
                component_name = item.get('componentName')
                component_version = item.get('componentVersionName')
                usages = item.get('usages', [])

                if not usages:
                    stats['missing_usage'] += 1
                    stats['non_compliant_list'].append({
                        'name': component_name,
                        'version': component_version,
                    })
                    print(f"[FAIL] {component_name} @ {component_version}: Missing Usage")
                else:
                    stats['compliant'] += 1
                    logger.debug(f"[PASS] {component_name} @ {component_version}: Usage={usages}")

            # Handle pagination
            components_url = None
            for link in data.get('_meta', {}).get('links', []):
                if link.get('rel') == 'next':
                    components_url = link.get('href')
                    break

        except Exception as e:
            logger.error(f"Failed to retrieve components: {e}")
            sys.exit(1)

    print("\n" + "="*80)
    print(" COMPLIANCE SUMMARY ".center(80, "="))
    print("="*80)
    print(f"Total Components with License Violations : {stats['total_violating']}")
    print(f"Compliant (Usage set)                    : {stats['compliant']}")
    print(f"Non-Compliant (Missing Usage)             : {stats['missing_usage']}")
    print("="*80 + "\n")

    if stats['non_compliant_list']:
        print("ERROR: One or more components are missing a Usage declaration.")
        print("Please set the Usage field in the Black Duck UI (or re-run carry-forward) before proceeding.")
        sys.exit(1)
    else:
        print("SUCCESS: All license-violating components have a Usage declared.")

def main():
    bd_url = get_env_var('BLACKDUCK_URL').rstrip('/')
    bd_token = get_env_var('BLACKDUCK_API_TOKEN')
    project_name = get_env_var('BLACKDUCK_PROJECT_NAME')
    curr_version_name = get_env_var('BLACKDUCK_VERSION')
    
    print("\n" + "="*80)
    print(" BLACK DUCK COMPLIANCE CHECK ".center(80, "="))
    print("="*80)
    print(f"Project:          {project_name}")
    print(f"Current Version:  {curr_version_name}")
    print("="*80)
    
    bearer_token = authenticate(bd_url, bd_token)
    project = get_project_by_name(bd_url, bearer_token, project_name)
    project_url = project['_meta']['href']
    
    curr_version = get_version_by_name(bd_url, bearer_token, project_url, curr_version_name)
    
    check_compliance(bd_url, bearer_token, curr_version['_meta']['href'])

if __name__ == "__main__":
    main()
