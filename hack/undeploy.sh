#!/bin/bash
#
# Undeploy everything in an orderly manner
#
# This script performs a complete teardown of the infrastructure and
# Kubernetes cluster. It runs the destroy playbook which handles:
# 1. Destroying Terraform infrastructure
# 2. Cleaning up any remaining resources
#
# Usage:
#   ./hack/undeploy.sh [provider]
#
# Arguments:
#   provider    Optional. Override provider (libvirt|aws). If not provided,
#               uses provider from ansible/inventory/group_vars/all.yml or
#               TERRAFORM_PROVIDER environment variable.
#
# Environment variables:
#   TERRAFORM_PROVIDER    Override provider selection (libvirt|aws)
#   FORCE                 Set to 'yes' to skip confirmation prompts
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Function to print colored output
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible is not installed or not in PATH"
        exit 1
    fi
    
    if [ ! -d "${ANSIBLE_DIR}" ]; then
        error "Ansible directory not found: ${ANSIBLE_DIR}"
        exit 1
    fi
    
    if [ ! -f "${ANSIBLE_DIR}/playbooks/destroy.yml" ]; then
        error "Destroy playbook not found: ${ANSIBLE_DIR}/playbooks/destroy.yml"
        exit 1
    fi
    
    info "Prerequisites check passed"
}

# Determine provider
determine_provider() {
    local provider="${1:-}"
    
    if [ -n "${provider}" ]; then
        if [[ "${provider}" != "libvirt" && "${provider}" != "aws" ]]; then
            error "Invalid provider: ${provider}. Must be 'libvirt' or 'aws'"
            exit 1
        fi
        echo "${provider}"
        return
    fi
    
    if [ -n "${TERRAFORM_PROVIDER:-}" ]; then
        if [[ "${TERRAFORM_PROVIDER}" != "libvirt" && "${TERRAFORM_PROVIDER}" != "aws" ]]; then
            error "Invalid TERRAFORM_PROVIDER: ${TERRAFORM_PROVIDER}. Must be 'libvirt' or 'aws'"
            exit 1
        fi
        echo "${TERRAFORM_PROVIDER}"
        return
    fi
    
    GROUP_VARS_FILE="${ANSIBLE_DIR}/inventory/group_vars/all.yml"
    if [ -f "${GROUP_VARS_FILE}" ]; then
        local provider_from_file
        provider_from_file=$(grep -E "^terraform_provider:" "${GROUP_VARS_FILE}" | sed 's/.*terraform_provider:[[:space:]]*\(.*\)/\1/' | tr -d '"' | tr -d "'" | xargs)
        if [ -n "${provider_from_file}" ] && [[ "${provider_from_file}" == "libvirt" || "${provider_from_file}" == "aws" ]]; then
            echo "${provider_from_file}"
            return
        fi
    fi
    
    # Auto-detect: check which provider has a state file
    for p in libvirt aws; do
        TERRAFORM_DIR="${PROJECT_ROOT}/terraform/${p}"
        STATE_FILE="${TERRAFORM_DIR}/terraform.tfstate"
        if [ -f "${STATE_FILE}" ]; then
            echo "${p}"
            return
        fi
    done
    
    error "Could not determine provider. Please specify explicitly."
    exit 1
}

# Confirm destruction
confirm_destruction() {
    if [ "${FORCE:-}" == "yes" ]; then
        return 0
    fi
    
    warn "=========================================="
    warn "WARNING: This will destroy all infrastructure!"
    warn "=========================================="
    echo ""
    read -p "Are you sure you want to proceed? Type 'yes' to continue: " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        info "Undeployment cancelled by user"
        exit 0
    fi
}

# Main undeployment function
main() {
    local provider_arg="${1:-}"
    local provider
    
    info "Starting undeployment..."
    info "Project root: ${PROJECT_ROOT}"
    
    check_prerequisites
    provider=$(determine_provider "${provider_arg}")
    
    info "Using provider: ${provider}"
    
    confirm_destruction
    
    # Export provider for Ansible
    export TERRAFORM_PROVIDER="${provider}"
    
    # Change to ansible directory
    cd "${ANSIBLE_DIR}"
    
    # Run the destroy playbook
    info "Running destroy playbook..."
    if ansible-playbook -i inventory/terraform_inventory.py playbooks/destroy.yml; then
        info "Undeployment completed successfully!"
        info ""
        info "All infrastructure has been destroyed."
    else
        error "Undeployment failed!"
        warn "Some resources may still exist. Check the output above for details."
        exit 1
    fi
}

# Run main function
main "$@"
