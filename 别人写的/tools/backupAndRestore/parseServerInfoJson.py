#!/usr/bin/python

import json
import sys


def parse_backup_policy(policy_json, server_property):
    policy_dict = json.loads(policy_json)
    if policy_dict.get('server'):
        if policy_dict.get('server').get(server_property):
            return policy_dict.get('server').get(server_property)
        return ""
    return ""


if __name__ == '__main__':
    result = parse_backup_policy(sys.argv[1], sys.argv[2])
    print result
