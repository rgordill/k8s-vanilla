#!/usr/bin/env python3
"""
Dynamic Ansible inventory script that reads from Terraform state.
"""

import json
import subprocess
import sys
import os

def get_terraform_output():
    """Get outputs from Terraform state."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    terraform_dir = os.path.join(os.path.dirname(os.path.dirname(script_dir)), 'terraform')
    
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
        sys.stderr.write(f"Error running terraform output: {e.stderr}\n")
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
        sys.exit(1)

if __name__ == '__main__':
    main()



