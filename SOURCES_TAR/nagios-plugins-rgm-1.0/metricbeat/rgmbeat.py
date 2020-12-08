#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys

class RGMArgumentParser(argparse.ArgumentParser):
    '''
    This override Python ArgumentParser class to allow sys.exit with a custom exit code
    '''
    def error(self, message):
        self.print_help(sys.stderr)
        self.exit(3, '%s\n' % message)