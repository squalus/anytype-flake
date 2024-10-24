#!/usr/bin/env python

# fix missing "resolved" and "integrity" fields in the npm package-lock.json
# https://github.com/npm/cli/issues/6301

import base64
import hashlib
import itertools
import json
import sys
import urllib.request
import time


def package_split(components):
    return [list(group) for k, group in itertools.groupby(components, lambda x: x == "node_modules") if not k]

def url_hash(url, timeout=60):
    remote = urllib.request.urlopen(url, timeout=timeout)
    max_file_size=1000*1024*1024
    hash = hashlib.sha512()
    total_read = 0
    while True:
        data = remote.read(4096)
        total_read += 4096
        if not data or total_read > max_file_size:
            break
        hash.update(data)
    digest = hash.digest()
    encoded_digest = base64.b64encode(digest).decode()
    return f'sha512-{encoded_digest}'

def url_hash_retry(url, retries=10, delay=1, timeout=60):
    for attempt in range(retries):
        try:
            val = url_hash(url, timeout=timeout)
            return val
        except Exception as e:
            print(f"Attempt {attempt + 1} failed with error: {e}")
            if attempt < retries - 1:
                time.sleep(delay)
            else:
                raise

if len(sys.argv) != 3:
    print(f'Usage: {sys.argv[0]} <input-lockfile> <output-lockfile>')
    sys.exit(1)

with open(sys.argv[1], 'r') as f:
    root = json.load(f)
    packages = root['packages']
for name in packages:
    if name == '':
        continue
    package = packages[name]
    has_integrity = 'integrity' in package
    has_resolved = 'resolved' in package
    if has_integrity and has_resolved:
        continue
    elif has_integrity != has_resolved:
        raise('unhandled case')
    version = package['version']
    print(f'needs fixing: name={name} version={version}')

    components = name.split('/')
    simplified=package_split(components)[-1]
    if 'name' in package:
        explicit_shortname = package['name']
        print(f'  explicit shortname={explicit_shortname}')
    else:
        explicit_shortname = None
    if len(simplified) == 2:
        orgname = simplified[0]
        shortname = explicit_shortname if explicit_shortname is not None else simplified[1]
        pathname = f'{orgname}/{shortname}'
    elif len(simplified) == 1:
        shortname = explicit_shortname if explicit_shortname is not None else simplified[0]
        pathname = shortname
    url = f"https://registry.npmjs.org/{pathname}/-/{shortname}-{version}.tgz"
    print(f'  guessed url={url}')
    sha512=url_hash_retry(url)
    print(f'  sha512={sha512}')
    package['resolved'] = url
    package['integrity'] = sha512

with open(sys.argv[2], 'w') as f:
    json.dump(root, f, indent='\t')

