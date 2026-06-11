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

def get_previous_component_data(bearer_token, version_url):
    logger.info(f"Retrieving LICENSE-violating component data from previous version {version_url}...")
    components_url = f"{version_url}/components?filter=policyCategory:LICENSE&limit=100"
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Accept': 'application/json'
    }
    component_data = {}
    name_to_usage = {}
    
    while components_url:
        try:
            response = requests.get(components_url, headers=headers, timeout=30)
            response.raise_for_status()
            data = response.json()
            items = data.get('items', [])
            
            for item in items:
                component_name = item.get('componentName')
                component_version = item.get('componentVersionName')
                comment = item.get('comment')
                usages = item.get('usages', [])
                
                key = f"{component_name}@{component_version}"
                component_data[key] = {
                    'comment': comment,
                    'usages': usages
                }
                
                # Store name-only usage if it's not already set or if this one has more data
                if component_name not in name_to_usage or (usages and not name_to_usage[component_name]):
                    name_to_usage[component_name] = usages
                
                logger.debug(f"Stored data for {key}: usages={usages}, comment={comment}")
            
            # Handle pagination
            components_url = None
            for link in data.get('_meta', {}).get('links', []):
                if link.get('rel') == 'next':
                    components_url = link.get('href')
                    break
                    
        except Exception as e:
            logger.error(f"Failed to retrieve components: {e}")
            break
            
    logger.info(f"Retrieved data for {len(component_data)} components ({len(name_to_usage)} unique names).")
    return component_data, name_to_usage

def carry_forward_data(url, bearer_token, current_version_url, previous_data, name_to_usage, dry_run=False):
    print("\n" + "="*80)
    print(" STEP 4: CARRYING FORWARD METADATA TO CURRENT VERSION ".center(80, "="))
    print("="*80)
    
    # Filter for LICENSE violations
    components_url = f"{current_version_url}/components?filter=policyCategory:LICENSE&limit=100"
    headers = {
        'Authorization': f'Bearer {bearer_token}',
        'Accept': 'application/json'
    }
    
    stats = {
        'considered': 0,
        'updated_usage': 0,
        'updated_comment': 0,
        'applied_total': 0,
        'skipped_no_match': 0,
        'skipped_no_change': 0,
        'errors': 0
    }
    
    while components_url:
        try:
            response = requests.get(components_url, headers=headers, timeout=30)
            response.raise_for_status()
            data = response.json()
            items = data.get('items', [])
            
            for item in items:
                component_name = item.get('componentName')
                component_version = item.get('componentVersionName')
                current_comment = item.get('comment')
                current_usages = item.get('usages', [])
                component_href = item['_meta']['href']
                policy_status = item.get('policyStatus', '')
                ignored = item.get('ignored', False)

                # Only process components that are actively in violation and
                # have not already been manually handled (ignored).
                if ignored:
                    logger.debug(f"[SKIP-IGNORED] {component_name}@{component_version}: already ignored, leaving for human review")
                    continue
                if policy_status != 'IN_VIOLATION':
                    logger.debug(f"[SKIP-STATUS] {component_name}@{component_version}: policyStatus={policy_status!r}, not IN_VIOLATION")
                    continue

                stats['considered'] += 1
                
                key = f"{component_name}@{component_version}"
                
                payload = {}
                update_reasons = []
                match_type = None
                
                # 1. Try exact match (name + version) for both Usage and Comment
                if key in previous_data:
                    prev_item = previous_data[key]
                    prev_comment = prev_item.get('comment')
                    prev_usages = prev_item.get('usages', [])
                    match_type = "EXACT"
                    
                    # Check if Usage needs update
                    if prev_usages and current_usages != prev_usages:
                        payload['usages'] = prev_usages
                        update_reasons.append(f"Usage: {current_usages} -> {prev_usages}")
                        stats['updated_usage'] += 1
                    
                    # Check if Comment needs update
                    if prev_comment and not current_comment:
                        payload['comment'] = prev_comment
                        update_reasons.append(f"Justification: '{prev_comment}'")
                        stats['updated_comment'] += 1
                
                # 2. If no exact match, try name-only match for Usage ONLY
                elif component_name in name_to_usage:
                    prev_usages = name_to_usage[component_name]
                    match_type = "NAME-ONLY"
                    
                    if prev_usages and current_usages != prev_usages:
                        payload['usages'] = prev_usages
                        update_reasons.append(f"Usage: {current_usages} -> {prev_usages}")
                        stats['updated_usage'] += 1
                
                if payload:
                    print(f"\n[UPDATE] {component_name} @ {component_version} ({match_type} match)")
                    for reason in update_reasons:
                        print(f"  - {reason}")
                    
                    if dry_run:
                        print(f"  - Action: (DRY RUN) Would apply update to {component_href}")
                        stats['applied_total'] += 1
                    else:
                        print(f"  - Action: Applying update...", end=" ", flush=True)
                        put_headers = {
                            'Authorization': f'Bearer {bearer_token}',
                            'Content-Type': 'application/vnd.blackducksoftware.bill-of-materials-6+json'
                        }
                        
                        try:
                            put_res = requests.put(component_href, headers=put_headers, json=payload, timeout=30)
                            put_res.raise_for_status()
                            print("SUCCESS")
                            stats['applied_total'] += 1
                        except Exception as e:
                            print(f"FAILED: {e}")
                            stats['errors'] += 1
                else:
                    if match_type:
                        # logger.debug(f"[-] SKIP: {key} already matches previous version or has no data to carry forward.")
                        stats['skipped_no_change'] += 1
                    else:
                        # logger.info(f"[-] SKIP: {key} not found in previous version data.")
                        stats['skipped_no_match'] += 1
            
            # Handle pagination
            components_url = None
            for link in data.get('_meta', {}).get('links', []):
                if link.get('rel') == 'next':
                    components_url = link.get('href')
                    break
                    
        except Exception as e:
            logger.error(f"Failed to retrieve current components: {e}")
            break
            
    print("\n" + "="*80)
    print(" FINAL SUMMARY ".center(80, "="))
    print("="*80)
    print(f"Total Candidates Considered:      {stats['considered']}")
    print(f"Total Components Updated:         {stats['applied_total']}")
    print(f"  - Usage updates:                {stats['updated_usage']}")
    print(f"  - Justification updates:        {stats['updated_comment']}")
    print(f"Total Skipped:                    {stats['skipped_no_match'] + stats['skipped_no_change']}")
    print(f"  - No match in previous:         {stats['skipped_no_match']}")
    print(f"  - Already matches/No data:      {stats['skipped_no_change']}")
    print(f"Errors encountered:               {stats['errors']}")
    print("="*80 + "\n")

def main():
    print("\n" + "="*80)
    print(" BLACK DUCK CARRY-FORWARD METADATA ".center(80, "="))
    print("="*80)
    
    bd_url = get_env_var('BLACKDUCK_URL').rstrip('/')
    bd_token = get_env_var('BLACKDUCK_API_TOKEN')
    project_name = get_env_var('BLACKDUCK_PROJECT_NAME')
    prev_version_name = get_env_var('BLACKDUCK_PREVIOUS_VERSION')
    curr_version_name = get_env_var('BLACKDUCK_VERSION')
    dry_run = get_env_var('DRY_RUN', required=False) == 'true'
    
    print(f"Project:          {project_name}")
    print(f"Previous Version: {prev_version_name}")
    print(f"Current Version:  {curr_version_name}")
    if dry_run:
        print(f"Mode:             DRY RUN (No changes will be made)")
    else:
        print(f"Mode:             LIVE (Changes will be applied)")
    print("="*80)
    
    bearer_token = authenticate(bd_url, bd_token)
    project = get_project_by_name(bd_url, bearer_token, project_name)
    project_url = project['_meta']['href']
    
    prev_version = get_version_by_name(bd_url, bearer_token, project_url, prev_version_name)
    curr_version = get_version_by_name(bd_url, bearer_token, project_url, curr_version_name)
    
    prev_data, name_to_usage = get_previous_component_data(bearer_token, prev_version['_meta']['href'])
    
    carry_forward_data(bd_url, bearer_token, curr_version['_meta']['href'], prev_data, name_to_usage, dry_run)
    
    print("Done.")

if __name__ == "__main__":
    main()
