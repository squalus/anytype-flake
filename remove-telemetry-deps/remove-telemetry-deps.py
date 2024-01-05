#!/usr/bin/env python3

import json
import sys
from pathlib import Path

if len(sys.argv) != 2:
    print(f'Usage: {sys.argv[0]} <input-dir>')
    sys.exit(1)

package_file = Path(sys.argv[1]) / 'package.json'
lock_file = Path(sys.argv[1]) / 'package-lock.json'

with open(package_file, 'r') as f:
    package = json.load(f)

with open(lock_file, 'r') as f:
    lock = json.load(f)

del(package['dependencies']['amplitude-js'])
del(package['dependencies']['@sentry/browser'])
del(package['dependencies']['@sentry/cli'])

del(lock['packages']['']['dependencies']['amplitude-js'])
del(lock['packages']['']['dependencies']['@sentry/browser'])
del(lock['packages']['']['dependencies']['@sentry/cli'])
del(lock['packages']['node_modules/amplitude-js'])
del(lock['packages']['node_modules/@sentry/browser'])
del(lock['packages']['node_modules/@sentry/cli'])

with open(package_file, 'w') as f:
    json.dump(package, f, indent='\t')

with open(lock_file, 'w') as f:
    json.dump(lock, f, indent='\t')

