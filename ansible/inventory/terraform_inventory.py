#!/usr/bin/env python3
"""
Dynamic Ansible inventory script that reads from Terraform state.
Supports multiple providers (libvirt, aws).

Usage:
  Set TERRAFORM_PROVIDER environment variable to 'libvirt' or 'aws'
  Default: auto-detect based on which has a terraform.tfstate file
"""

import json
import subprocess
import sys
import os

def get_terraform_dir():
    """Get the appropriate Terraform directory based on provider."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    terraform_base = os.path.join(os.path.dirname(os.path.dirname(script_dir)), 'terraform')
    
    # Check for TERRAFORM_PROVIDER environment variable
    provider = os.environ.get('TERRAFORM_PROVIDER', '').lower()
    
    if provider in ['libvirt', 'aws']:
        return os.path.join(terraform_base, provider)
    
    # Auto-detect: check which provider has a state file
    for p in ['libvirt', 'aws']:
        provider_dir = os.path.join(terraform_base, p)
        state_file = os.path.join(provider_dir, 'terraform.tfstate')
        if os.path.exists(state_file):
            return provider_dir
    
    # Default to libvirt
    return os.path.join(terraform_base, 'libvirt')

def get_terraform_output():
    """Get outputs from Terraform state."""
    terraform_dir = get_terraform_dir()
    
    try:
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            cwd=terraform_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"Error running terraform output in {terraform_dir}: {e.stderr}\n")
        return {}
    except json.JSONDecodeError as e:
        sys.stderr.write(f"Error parsing terraform output: {e}\n")
        return {}
    except FileNotFoundError:
        sys.stderr.write("Terraform not found in PATH\n")
        return {}

def build_inventory(tf_output):
    """Build Ansible inventory from Terraform output."""
    inventory = {
        '_meta': {
            'hostvars': {}
        },
        'all': {
            'children': ['k8s_nodes']
        },
        'k8s_nodes': {
            'hosts': []
        }
    }
    
    if not tf_output:
        return inventory
    
    # Get ansible_inventory output
    ansible_inventory = tf_output.get('ansible_inventory', {}).get('value', {})
    k8s_nodes = ansible_inventory.get('k8s_nodes', {}).get('hosts', {})
    
    for hostname, hostvars in k8s_nodes.items():
        inventory['k8s_nodes']['hosts'].append(hostname)
        inventory['_meta']['hostvars'][hostname] = hostvars
    
    return inventory

def main():
    """Main entry point."""
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        tf_output = get_terraform_output()
        inventory = build_inventory(tf_output)
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        # Return empty dict for host-specific vars (we use _meta)
        print(json.dumps({}))
    else:
        sys.stderr.write("Usage: terraform_inventory.py --list | --host <hostname>\n")
        sys.stderr.write("\nEnvironment variables:\n")
        sys.stderr.write("  TERRAFORM_PROVIDER: 'libvirt' or 'aws' (auto-detected if not set)\n")
        sys.exit(1)

if __name__ == '__main__':
    main()
