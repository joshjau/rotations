#!/usr/bin/env python3

import argparse
import datetime
import sys
from os import path, chdir, scandir

parser = argparse.ArgumentParser()
parser.add_argument("--mtime", dest="mtime", help="Timestamp used to prevent changing metada from older files.")
parser.add_argument("--version", dest="version", help="World of Warcraft version.")
args = parser.parse_args()

mtime = int(args.mtime)
version = args.version

chdir(path.join(path.dirname(sys.path[0]), '..', '..', 'hero-dbc'))

# Prepend meta infos to every lua parsed files
luaMetas = f'-- Generated using WoW {version} client data on {datetime.datetime.now().isoformat()}.\n'
dbcDirs = [path.join('HeroDBC', 'DBC'), path.join('HeroDBC', 'Dev', 'Unfiltered')]
for dbcDir in dbcDirs:
    with scandir(dbcDir) as iterator:
        for entry in iterator:
            entryName = entry.name
            if not entryName.startswith('.') and entryName.endswith('.lua') and entry.is_file():
                # Prevent changing metadata from older files
                if path.getmtime(entry.path) <= mtime:
                    continue
                # Read the content, skipping the old header
                lines = []
                with open(entry.path, 'r') as entryFile:
                    first_line = True
                    for line in entryFile:
                        if first_line and line.startswith('-- Generated using WoW'):
                            first_line = False
                            continue
                        lines.append(line)
                        first_line = False

                # Rewrite the file adding the new header then the rest of the content
                with open(entry.path, 'w') as entryFile:
                    entryFile.write(luaMetas)
                    entryFile.writelines(lines)

# Generate metaFile
with open(path.join(path.join('HeroDBC', 'DBC'), 'Meta.lua'), 'w', encoding='utf-8') as file:
    file.write(f'HeroDBC.DBC.metaVersion = "{version}"\n')
    file.write(f'HeroDBC.DBC.metaTime = "{datetime.datetime.now().isoformat()}"\n')