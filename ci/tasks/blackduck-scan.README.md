# Black Duck Carry-Forward Script

This script automates the process of carrying forward component metadata (Usage and Justifications) from a previous Black Duck project version to the current one. This is particularly useful for resolving recurring license policy violations that have already been reviewed and justified in a prior release.

## How it Works

1.  **Authentication**: Connects to the Black Duck API using an API token to obtain a bearer token.
2.  **Version Resolution**: Locates the project and both the current and previous versions specified.
3.  **Data Collection**: Retrieves all components from the **previous version** that have either a `comment` (justification) or specific `usages` set.
4.  **Metadata Carry-Forward**:
    *   Iterates through components in the **current version** that have active `LICENSE` policy violations.
    *   If a component matches (by name and version) an entry in the previous version:
        *   **Usage**: If the current usage differs from the previous usage, it is updated to match.
        *   **Justification**: If the current component has no comment but the previous one did, the justification is copied over.
5.  **Compliance Check**:
    *   Iterates through all components in the **current version** that have active `LICENSE` policy violations.
    *   Fails the build if any component is missing either a **Usage** or a **Justification (Comment)**.
    *   This ensures that all security and compliance requirements are met before the release proceeds.
6.  **Logging**: Provides verbose output for every match and update performed.

## Environment Variables

| Variable | Description | Required |
| --- | --- | --- |
| `BLACKDUCK_URL` | The base URL of your Black Duck instance. | Yes |
| `BLACKDUCK_API_TOKEN` | Your Black Duck API token. | Yes |
| `BLACKDUCK_PROJECT_NAME` | The name of the project in Black Duck. | Yes |
| `BLACKDUCK_VERSION` | The current project version (e.g., `5.5.1`). | Yes |
| `BLACKDUCK_PREVIOUS_VERSION` | The previous project version to copy data from (e.g., `5.5.0`). | Yes |
| `DRY_RUN` | Set to `true` to log planned changes without applying them. | No |

## Usage

```bash
export BLACKDUCK_URL='https://blackduck.example.com'
export BLACKDUCK_API_TOKEN='your-token'
export BLACKDUCK_PROJECT_NAME='My-Project'
export BLACKDUCK_VERSION='1.1.0'
export BLACKDUCK_PREVIOUS_VERSION='1.0.0'

# Dry run first to verify matches
export DRY_RUN=true
python3 ci/scripts/blackduck-carry-forward-justifications.py

# Apply changes
export DRY_RUN=false
python3 ci/scripts/blackduck-carry-forward-justifications.py
```
