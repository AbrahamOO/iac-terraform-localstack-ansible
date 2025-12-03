#!/usr/bin/env python3

import json
import subprocess
import sys
import os

def get_terraform_output():
    """
    Retrieves Terraform output and converts it to Ansible inventory format.
    """
    terraform_dir = os.path.join(os.path.dirname(__file__), '..', 'terraform')

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
        print(f"Error running terraform output: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing terraform output: {e}", file=sys.stderr)
        sys.exit(1)

def build_inventory(terraform_output):
    """
    Builds Ansible inventory from Terraform output.
    """
    inventory = {
        'all': {
            'hosts': [],
            'vars': {
                'ansible_connection': 'local',
                'ansible_python_interpreter': '/usr/bin/python3'
            }
        },
        'webservers': {
            'hosts': []
        },
        '_meta': {
            'hostvars': {}
        }
    }

    # Extract instance information
    if 'instance_private_ip' in terraform_output:
        private_ip = terraform_output['instance_private_ip']['value']
        instance_id = terraform_output.get('instance_id', {}).get('value', 'unknown')

        # Add host to inventory
        inventory['all']['hosts'].append(private_ip)
        inventory['webservers']['hosts'].append(private_ip)

        # Add host-specific variables
        inventory['_meta']['hostvars'][private_ip] = {
            'instance_id': instance_id,
            'ansible_host': 'localhost',
            'ansible_connection': 'local'
        }

    return inventory

def main():
    """
    Main entry point for the dynamic inventory script.
    """
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        terraform_output = get_terraform_output()
        inventory = build_inventory(terraform_output)
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        # Return empty dict for host-specific variables (already in _meta)
        print(json.dumps({}))
    else:
        print("Usage: {} --list or {} --host <hostname>".format(sys.argv[0], sys.argv[0]), file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
