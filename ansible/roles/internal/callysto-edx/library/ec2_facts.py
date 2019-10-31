#!/usr/bin/env python
#
# This module intentionally does nothing.
# It's only used to act as a placeholder for the
# legacy ec2_facts module that edx requires.

from ansible.module_utils.basic import AnsibleModule

module = AnsibleModule(
    argument_spec=dict(),
    supports_check_mode=True,
)

result = dict()
module.exit_json(**result)
