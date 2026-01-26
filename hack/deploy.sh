#!/bin/bash
#
# Deploy infrastructure and Kubernetes cluster
#
# This script provisions infrastructure using Terraform and configures
# Kubernetes using Ansible. It follows the full deployment workflow:
# 1. Provision infrastructure (Terraform)
# 2. Configure Kubernetes (Ansible)
#
# Usage:
#   ./hack/deploy.sh [provider]
#
# Arguments:
#   provider    Optional. Override provider (libvirt|aws). If not provided,
#               uses provider from ansible/inventory/group_vars/all.yml or
#               TERRAFORM_PROVIDER environment variable.
#
# Environment variables:
#   TERRAFORM_PROVIDER    Override provider selection (libvirt|aws)
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
    
    if [ ! -f "${ANSIBLE_DIR}/playbooks/site.yml" ]; then
        error "Main playbook not found: ${ANSIBLE_DIR}/playbooks/site.yml"
        exit 1
    fi
    
    # Check if inventory script is executable
    INVENTORY_SCRIPT="${ANSIBLE_DIR}/inventory/terraform_inventory.py"
    if [ -f "${INVENTORY_SCRIPT}" ] && [ ! -x "${INVENTORY_SCRIPT}" ]; then
        warn "Making inventory script executable..."
        chmod +x "${INVENTORY_SCRIPT}"
    fi
    
    info "Prerequisites check passed"
}

# Determine provider
determine_provider() {
    local provider="${1:-}"
    
    if [ -n "${provider}" ]; then
        # Provider provided as argument
        if [[ "${provider}" != "libvirt" && "${provider}" != "aws" ]]; then
            error "Invalid provider: ${provider}. Must be 'libvirt' or 'aws'"
            exit 1
        fi
        echo "${provider}"
        return
    fi
    
    # Check environment variable
    if [ -n "${TERRAFORM_PROVIDER:-}" ]; then
        if [[ "${TERRAFORM_PROVIDER}" != "libvirt" && "${TERRAFORM_PROVIDER}" != "aws" ]]; then
            error "Invalid TERRAFORM_PROVIDER: ${TERRAFORM_PROVIDER}. Must be 'libvirt' or 'aws'"
            exit 1
        fi
        echo "${TERRAFORM_PROVIDER}"
        return
    fi
    
    # Try to read from group_vars/all.yml
    GROUP_VARS_FILE="${ANSIBLE_DIR}/inventory/group_vars/all.yml"
    if [ -f "${GROUP_VARS_FILE}" ]; then
        local provider_from_file
        provider_from_file=$(grep -E "^terraform_provider:" "${GROUP_VARS_FILE}" | sed 's/.*terraform_provider:[[:space:]]*\(.*\)/\1/' | tr -d '"' | tr -d "'" | xargs)
        if [ -n "${provider_from_file}" ] && [[ "${provider_from_file}" == "libvirt" || "${provider_from_file}" == "aws" ]]; then
            echo "${provider_from_file}"
            return
        fi
    fi
    
    # Default to libvirt
    warn "No provider specified, defaulting to 'libvirt'"
    echo "libvirt"
}

# Main deployment function
main() {
    local provider_arg="${1:-}"
    local provider
    
    info "Starting deployment..."
    info "Project root: ${PROJECT_ROOT}"
    
    check_prerequisites
    provider=$(determine_provider "${provider_arg}")
    
    info "Using provider: ${provider}"
    
    # Export provider for Ansible
    export TERRAFORM_PROVIDER="${provider}"
    
    # Set Ansible temp directory to avoid permission issues
    ANSIBLE_TMP_DIR="${PROJECT_ROOT}/.ansible-tmp"
    mkdir -p "${ANSIBLE_TMP_DIR}"
    export ANSIBLE_LOCAL_TMP="${ANSIBLE_TMP_DIR}"
    export TMPDIR="${ANSIBLE_TMP_DIR}"
    
    # Disable multiprocessing to avoid /dev/shm issues
    export ANSIBLE_FORKS=1
    export ANSIBLE_STRATEGY=linear
    
    # Change to ansible directory
    cd "${ANSIBLE_DIR}"
    
    # Install Ansible collections if needed
    if [ -f "requirements.yml" ]; then
        info "Installing/updating Ansible collections..."
        ansible-galaxy collection install -r requirements.yml || warn "Some collections may have failed to install"
    fi
    
    # Run the main playbook (provision + configure)
    info "Running deployment playbook..."
    if ansible-playbook -f 1 -i inventory/terraform_inventory.py playbooks/site.yml; then
        info "Deployment completed successfully!"
        info ""
        info "Next steps:"
        info "  - SSH into the VM to access the cluster"
        info "  - Copy kubeconfig: scp fedora@<vm-ip>:/home/fedora/.kube/config ./kubeconfig"
        info "  - Export KUBECONFIG: export KUBECONFIG=./kubeconfig"
    else
        error "Deployment failed!"
        exit 1
    fi
}

# Run main function
main "$@"
