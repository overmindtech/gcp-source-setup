#!/bin/bash

# Script to add IAM policy bindings to a service account in GCP
# Takes GCP Project ID and Overmind service account as arguments
#
# Usage: ./overmind-gcp-source-setup.sh <project-id> <service-account-email>
#
# NOTE: The Overmind service account should be the service account email presented
# in the Overmind application when creating a new GCP source.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Check if both arguments are provided
if [[ $# -ne 2 ]]; then
    echo "ERROR: Both project ID and service account email are required"
    echo "Usage: $0 <project-id> <service-account-email>"
    exit 1
fi

# Get arguments
GCP_PROJECT_ID="$1"
GCP_OVERMIND_SA="$2"

# Check if GCP_PROJECT_ID is empty
if [[ -z "${GCP_PROJECT_ID}" ]]; then
    echo "ERROR: GCP Project ID cannot be empty"
    exit 1
fi

# Check if GCP_OVERMIND_SA is empty
if [[ -z "${GCP_OVERMIND_SA}" ]]; then
    echo "ERROR: Overmind service account email cannot be empty"
    echo "NOTE: Use the service account email presented in the Overmind application when creating a GCP source"
    exit 1
fi

# Export the variables to the environment so they can be used in subsequent commands
export GCP_PROJECT_ID
export GCP_OVERMIND_SA

# Save the variables to a local file for other scripts to use
echo "export GCP_PROJECT_ID=\"${GCP_PROJECT_ID}\"" > ./.gcp-source-setup-env
echo "export GCP_OVERMIND_SA=\"${GCP_OVERMIND_SA}\"" >> ./.gcp-source-setup-env

echo "Using GCP Project ID: ${GCP_PROJECT_ID}"
echo "Service Account: ${GCP_OVERMIND_SA}"

# Source the roles file
source "$(dirname "$0")/overmind-gcp-roles.sh"

# Create custom role for additional BigQuery and Spanner permissions
echo "Creating custom role for additional BigQuery and Spanner permissions..."
if gcloud iam roles create overmindCustomRole \
    --project="${GCP_PROJECT_ID}" \
    --title="Overmind Custom Role" \
    --description="Custom role for Overmind service account with additional BigQuery and Spanner permissions" \
    --permissions="bigquery.transfers.get,spanner.databases.get,spanner.databases.list" \
    --quiet > /dev/null 2>&1; then
    echo "✓ Successfully created custom role: overmindCustomRole"
else
    echo "ℹ Custom role may already exist, continuing..."
fi

# Display the roles that will be added
echo ""
echo "This script will assign the following predefined GCP roles and custom role to ${GCP_OVERMIND_SA} on the project ${GCP_PROJECT_ID}:"
echo ""

for ROLE in "${ROLES[@]}"; do
    echo "  - ${ROLE}"
done

echo "  - projects/${GCP_PROJECT_ID}/roles/overmindCustomRole (custom role with additional BigQuery and Spanner permissions)"
echo ""
echo "These permissions are read-only and allow Overmind to inspect your GCP resources without making any changes."
echo ""

# Ask for confirmation
read -p "Do you want to continue? (Yes/No): " CONFIRMATION
if [[ ! "$(echo "$CONFIRMATION" | tr '[:upper:]' '[:lower:]')" =~ ^(yes|y)$ ]]; then
    echo "Operation canceled by user."
    exit 0
fi

# Counter for successful operations
SUCCESS_COUNT=0
TOTAL_ROLES=${#ROLES[@]}
CUSTOM_ROLE="projects/${GCP_PROJECT_ID}/roles/overmindCustomRole"
TOTAL_ROLES=$((TOTAL_ROLES + 1))  # Add 1 for the custom role

echo ""
echo "Starting to add ${TOTAL_ROLES} IAM policy bindings..."
echo "----------------------------------------"

# Loop through each role and add the policy binding
for ROLE in "${ROLES[@]}"; do
    echo "Adding role: ${ROLE}"

    if gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="serviceAccount:${GCP_OVERMIND_SA}" \
        --role="${ROLE}" \
        --quiet > /dev/null 2>&1; then
        echo "✓ Successfully added role: ${ROLE}"
        ((SUCCESS_COUNT++)) || true
    else
        echo "✗ Failed to add role: ${ROLE}"
        # Print the error output
        gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
            --member="serviceAccount:${GCP_OVERMIND_SA}" \
            --role="${ROLE}" \
            --quiet
        exit 1
    fi
done

# Add the custom role
echo "Adding custom role: ${CUSTOM_ROLE}"
if gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
    --member="serviceAccount:${GCP_OVERMIND_SA}" \
    --role="${CUSTOM_ROLE}" \
    --quiet > /dev/null 2>&1; then
    echo "✓ Successfully added custom role: ${CUSTOM_ROLE}"
    ((SUCCESS_COUNT++)) || true
else
    echo "✗ Failed to add custom role: ${CUSTOM_ROLE}"
    # Print the error output
    gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
        --member="serviceAccount:${GCP_OVERMIND_SA}" \
        --role="${CUSTOM_ROLE}" \
        --quiet
    exit 1
fi

echo "----------------------------------------"
echo "✓ All IAM policy bindings completed successfully!"
echo "✓ Added ${SUCCESS_COUNT}/${TOTAL_ROLES} roles to service account: ${GCP_OVERMIND_SA}"
echo "✓ Project: ${GCP_PROJECT_ID}"
echo ""
echo "The following environment variables have been set for this terminal session:"
echo "  GCP_PROJECT_ID=${GCP_PROJECT_ID}"
echo "  GCP_OVERMIND_SA=${GCP_OVERMIND_SA}"
echo ""
echo "These variables have also been saved to ./.gcp-source-setup-env for other scripts to use."
echo "You can use these variables in subsequent commands."
