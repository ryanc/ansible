#!/usr/bin/env python

from __future__ import print_function

import sys
import requests
import re
import argparse

from urlparse import urljoin

PATTERNS = (
    #(re.compile(r": (\S+)\[.+logged in"), "{0} joined the game"),
    (re.compile(r"(\S+) (joined|left) the game"), "{0} {1} the game"),
    (re.compile(r"\[(\S+): Gave (\d+) \[(.+)\] to (\S+)\]"), ":police_officer: {0} gave {1} \"{2}\" to {3}"),
    (re.compile(r"(\S+) was (\S+) by (\S+)"), ":skull: {0} was {1} by {2}"),
    (re.compile(r"(\S+) tried to swim in lava"), ":skull: {0} tried to swim in lava"),
    (re.compile(r"(\S+) fell from a high place"), ":skull: {0} fell from a high place"),
    (re.compile(r"\[(\S+): Set own game mode to (.+) Mode\]"), ":police_officer: {0} set game mode to '{1}' mode"),
)


def print_err(s):
    print(s, file=sys.stderr)
    sys.stderr.flush()


def ok():
    print("OK")
    sys.stdout.flush()


def cli_parse(args):
    parser = argparse.ArgumentParser()
    opt = parser.add_argument
    opt("--config", "-c", dest="config", type=parse_kv_file)
    opt("--confirm", action="store_const", dest="confirm", const=True, default=True)
    opt("--no-confirm", action="store_const", dest="confirm", const=False)
    opt("--verbose", "-v", action="store_true")
    opt("--debug", "-d", action="store_true")
    cli_args = parser.parse_args(args[1:])
    return cli_args, parser


def parse_kv_file(f, mode="r"):
    if isinstance(f, str):
        f = open(f, mode)

    kv = {}
    with f:
        for line in f:
            k, v = line.partition("=")[::2]
            kv[k.strip().lower()] = v.strip()

    return kv


class DiscordHook:
    def __init__(self, hook_id, hook_token):
        url_path = "/".join([hook_id, hook_token])
        url = urljoin("https://discordapp.com/api/webhooks/", url_path)
        self.url = url

    def send(self, content):
        data = {"content": content}
        r = requests.post(self.url, data=data)
        r.raise_for_status()
        return r


def loop(handler, confirm=True):
    if confirm:
        ok()

    while 1:
        try:
            line = sys.stdin.readline()
        except KeyboardInterrupt:
            print_err("\nreceived sigint, exiting")
            break

        if not line:
            break

        for pattern, fmt in PATTERNS:
            match = pattern.search(line.strip())

            if match:
                message = fmt.format(*match.groups())

                try:
                    handler.send(message)
                except Exception as e:
                    print_err(e)
                    continue

        if confirm:
            ok()


def main(argv):
    args, _ = cli_parse(argv)

    if args.debug:
        print("started with args {0}".format(vars(args)))

    webhook_id = args.config.get("webhook_id")
    webhook_token = args.config.get("webhook_token")

    if webhook_id is None:
        raise SystemExit("webhook_id is unset")
    if webhook_token is None:
        raise SystemExit("webhook_token is unset")

    handler = DiscordHook(webhook_id, webhook_token)

    return loop(handler, confirm=args.confirm)


raise SystemExit(main(sys.argv))
