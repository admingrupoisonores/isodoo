#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import os
import configparser
import argparse

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

for key, value in os.environ.items():
    if key.startswith("OCONF_"):
        config_key = key[6:].lower()
        config.set("options", config_key, value)

with open(args.output, "w") as configfile:
    config.write(configfile)
