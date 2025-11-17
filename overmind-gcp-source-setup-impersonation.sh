#!/bin/bash

# Script to add IAM policy bindings to a service account in GCP Takes GCP
# Project ID, Overmind service account and Impersonation service account as
# arguments
#
# Usage: ./overmind-gcp-source-setup-impersonation.sh <project-id>
# <overmind-service-account-email> <impersonation-service-account-email>
#
# NOTE: The service accounts should be the service account emails
# presented in the Overmind application when creating a new GCP source.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Check if both arguments are provided
if [[ $# -ne 3 ]]; then
    echo "ERROR: All of the following arguments are required: project ID, overmind service account email and impersonation service account email"
    echo "Usage: $0 <project-id> <overmind-service-account-email> <impersonation-service-account-email>"
    exit 1
fi

# Get arguments
GCP_PROJECT_ID="$1"
GCP_OVERMIND_SA="$2"
GCP_IMPERSONATION_SA="$3"

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

# Check if GCP_IMPERSONATION_SA is empty
if [[ -z "${GCP_IMPERSONATION_SA}" ]]; then
    echo "ERROR: Impersonation service account email cannot be empty"
    echo "NOTE: Use the service account email presented in the Impersonation application when creating a GCP source"
    exit 1
fi

# Grant the necessary permissions to the Overmind Service Account to access the resources in the project
source "$(dirname "$0")/overmind-gcp-source-setup.sh" "${GCP_PROJECT_ID}" "${GCP_OVERMIND_SA}"

echo "Impersonation Service Account: ${GCP_IMPERSONATION_SA}"

# Grant the necessary permissions to the Impersonation Service Account to impersonate the Overmind Service Account
gcloud iam service-accounts add-iam-policy-binding \
    "${GCP_IMPERSONATION_SA}" \
    --project "${GCP_PROJECT_ID}" \
    --member="serviceAccount:${GCP_OVERMIND_SA}" \
    --role="roles/iam.serviceAccountTokenCreator"

# Save the variables to a local file for other scripts to use. This needs to be done after the source setup script is run to ensure the target file is not overwritten.
echo "export GCP_IMPERSONATION_SA=\"${GCP_IMPERSONATION_SA}\"" >> ./.gcp-source-setup-env
