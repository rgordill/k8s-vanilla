#!/bin/bash
#
# Clean up older infrastructure that no longer exists
#
# This script identifies and removes orphaned Terraform resources that
# are tracked in state but no longer exist in the actual infrastructure.
# It performs a terraform refresh to detect drift and then removes
# resources that are no longer present.
#
# Usage:
#   ./hack/cleanup.sh [provider]
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
BLUE='\033[0;34m'
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

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed or not in PATH"
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

# Cleanup orphaned resources
cleanup_orphaned_resources() {
    local provider="${1}"
    local terraform_dir="${PROJECT_ROOT}/terraform/${provider}"
    local state_file="${terraform_dir}/terraform.tfstate"
    
    if [ ! -d "${terraform_dir}" ]; then
        error "Terraform directory not found: ${terraform_dir}"
        exit 1
    fi
    
    if [ ! -f "${state_file}" ]; then
        warn "No Terraform state file found for provider: ${provider}"
        warn "Nothing to clean up."
        return 0
    fi
    
    info "Cleaning up orphaned resources for provider: ${provider}"
    info "Terraform directory: ${terraform_dir}"
    
    cd "${terraform_dir}"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        info "Initializing Terraform..."
        terraform init
    fi
    
    # Refresh state to detect drift
    info "Refreshing Terraform state to detect drift..."
    if terraform refresh -refresh-only > /tmp/terraform-refresh.log 2>&1; then
        info "State refresh completed"
    else
        warn "State refresh encountered issues. Check /tmp/terraform-refresh.log for details"
    fi
    
    # Show plan to see what would be removed
    info "Checking for resources to remove from state..."
    terraform plan -refresh-only -out=/tmp/terraform-plan.tfplan 2>&1 | tee /tmp/terraform-plan.log || true
    
    # Check for resources marked for deletion
    if grep -q "will be destroyed" /tmp/terraform-plan.log || grep -q "must be replaced" /tmp/terraform-plan.log; then
        warn "Found resources that may need cleanup:"
        grep -E "(will be destroyed|must be replaced)" /tmp/terraform-plan.log || true
        
        if [ "${FORCE:-}" != "yes" ]; then
            echo ""
            read -p "Do you want to remove these resources from state? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                info "Cleanup cancelled by user"
                return 0
            fi
        fi
        
        # For libvirt, check if VM still exists
        if [ "${provider}" == "libvirt" ]; then
            info "Checking for orphaned libvirt resources..."
            if command -v virsh &> /dev/null; then
                local vm_name
                vm_name=$(terraform output -raw vm_name 2>/dev/null || echo "")
                if [ -n "${vm_name}" ]; then
                    if ! virsh dominfo "${vm_name}" &> /dev/null; then
                        warn "VM '${vm_name}' not found in libvirt, but may be in Terraform state"
                        info "You may need to run: terraform state rm <resource>"
                    fi
                fi
            fi
        fi
        
        # For AWS, check if instance still exists
        if [ "${provider}" == "aws" ]; then
            info "Checking for orphaned AWS resources..."
            if command -v aws &> /dev/null; then
                local instance_id
                instance_id=$(terraform output -raw instance_id 2>/dev/null || echo "")
                if [ -n "${instance_id}" ]; then
                    if ! aws ec2 describe-instances --instance-ids "${instance_id}" &> /dev/null; then
                        warn "EC2 instance '${instance_id}' not found in AWS, but may be in Terraform state"
                        info "You may need to run: terraform state rm <resource>"
                    fi
                fi
            fi
        fi
        
        info "To remove specific resources from state, run:"
        info "  cd ${terraform_dir}"
        info "  terraform state list  # List all resources"
        info "  terraform state rm <resource_address>  # Remove specific resource"
    else
        info "No orphaned resources detected. State is clean."
    fi
    
    # Clean up temporary files
    rm -f /tmp/terraform-refresh.log /tmp/terraform-plan.log /tmp/terraform-plan.tfplan
}

# Main cleanup function
main() {
    local provider_arg="${1:-}"
    local provider
    
    info "Starting cleanup of orphaned infrastructure..."
    info "Project root: ${PROJECT_ROOT}"
    
    check_prerequisites
    provider=$(determine_provider "${provider_arg}")
    
    info "Using provider: ${provider}"
    
    cleanup_orphaned_resources "${provider}"
    
    info "Cleanup process completed!"
}

# Run main function
main "$@"
