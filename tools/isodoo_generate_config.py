#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import os
import configparser
import argparse
from collections import defaultdict

parser = argparse.ArgumentParser(
    description="Collects OCONF_ environment variables and saves them to an .conf file"
)
parser.add_argument("output", help="Path to the output .conf file")
args = parser.parse_args()

config = configparser.ConfigParser()

if os.path.exists(args.output):
    config.read(args.output)
    if not config.has_section("options"):
        config.add_section("options")
else:
    config.add_section("options")

to_write = defaultdict(dict)
for key, value in os.environ.items():
    if key.startswith("OCONF__"):
        _, config_section, config_key = key.split("__", 2)
        to_write[config_section][config_key] = value

for config_section, config_values in to_write.items():
    if not config.has_section(config_section):
        config.add_section(config_section)
    for config_key, value in config_values.items():
        config.set(config_section, config_key, value)

with open(args.output, "w") as configfile:
    config.write(configfile)
