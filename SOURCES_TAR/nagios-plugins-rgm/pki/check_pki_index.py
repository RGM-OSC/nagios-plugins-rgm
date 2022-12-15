#!/srv/rgm/python-rgm/bin/python3
# -*- coding: utf-8 -*-

'''
Nagios plugin to check Certificate near expiration from OpenSSL PKI index file
'''

__author__ = 'Eric Belhomme'
__copyright__ = '2022, SCC'
__credits__ = [__author__]
__license__ = 'GPL'
__version__ = '0.1.0'
__maintainer__ = __author__


import sys
import re
import requests
import argparse
from datetime import datetime, timedelta


pattern_valid = re.compile(
    r'^V\s+(?P<date>\d+Z)\s+(?P<serial>[\dA-F]+)\s+(?P<filename>\S+)\s+(?P<dn>\/.*)$'
)

NAGIOS_RC_OK = 0
NAGIOS_RC_WARNING = 1
NAGIOS_RC_CRITICAL = 2
NAGIOS_RC_UNKNOWN = 3
NAGIOS_RC = [
    "OK",
    "WARNING",
    "CRITICAL",
    "UNKNOWN"
]


class ValidCert:
    # class variable to iterate over instanciated objects
    _registry = []
    _now = datetime.now()

    def __init__(self, date: str, serial: str, filename: str, dn: str) -> None:
        self.validuntil = datetime.strptime(date, '%y%m%d%H%M%SZ')
        self.daystoexpire = (self.validuntil - self._now).days
        self.serial = serial
        self.filename = filename
        self.dn = {}
        self.dn['all'] = dn
        for i in dn.split('/'):
            for j in ('C', 'ST', 'L', 'O', 'OU', 'CN', 'emailAddress'):
                if i.startswith('{}='.format(j)):
                    self.dn[j] = i[len(j)+1:]
                    break
        self._registry.append(self)

    def is_exhausted(self) -> bool:
        if self.daystoexpire < 0:
            return True
        return False

    def is_warning(self) -> bool:
        if self.daystoexpire <= args.warning and self.daystoexpire > args.critical:
            return True
        return False

    def is_critical(self) -> bool:
        if self.daystoexpire <= args.critical or self.is_exhausted():
            return True
        return False

    @staticmethod
    def get_valids() -> list:
        r = []
        for i in ValidCert._registry:
            if not i.is_warning() and not i.is_critical():
                r.append(i)
        return r

    @staticmethod
    def get_warnings() -> list:
        r = []
        for i in ValidCert._registry:
            if i.is_warning():
                r.append(i)
        return r

    @staticmethod
    def get_criticals() -> list:
        r = []
        for i in ValidCert._registry:
            if i.is_critical():
                r.append(i)
        return r

    def __str__(self) -> str:
        return "cn: {}, serial: {}, valid until: {}".format(
            self.dn['CN'],
            self.serial,
            self.validuntil.isoformat()
        )



if __name__ == '__main__':
    '''
    1. utiliser argparse pour passer en argument :
        -U, --url : URL du fichier index à récupérer via HTTP
        -W, --warning : délai (en jours) au-delà duquel le check doit retourner un warning (RC-code = 1)
        -C, --critical : délai (en jours) au-delà duquel le check doit retourner un critical (RC-code = 2)
   
    2. parser le fichier 'index.txt' d'une PKI openssl ()
        référence : https://pki-tutorial.readthedocs.io/en/latest/cadb.html
   
    3. pour chaque certificat émis *valide* (commençant par 'V') on vérifie si il est :
        - OK ?
        - Warning ?
        - Critical ?
   
    4. le check doit retourner sur la sortie standard (STDOUT) pour chaque certificat valide, une ligne :
        - valide : "OK - certificate CN=<CN extrait du DN> (serial <serial number du cert>) valid until <date>"
        - warning: "WARNING - certificate CN=<CN extrait du DN> (serial <serial number du cert>) about to expire on <date>"
        - critical: "CRITICAL - certificate CN=<CN extrait du DN> (serial <serial number du cert>) about to expire on <date>" *ou* exipred on <date>
   
    5. la premire ligne a être imprimée sur STDOUT doit être de la forme :
        "OK|WARNING|CRITICAL - x certs OK, x certs warning, x certs criticaln"
    '''

    rc_code = NAGIOS_RC_UNKNOWN

    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin to check Certificate near expiration from OpenSSL PKI index file
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument("-u","--url", type=str, help="URL of the index file to retrieve via HTTP", required=True)
    parser.add_argument("-w","--warning", type=int, help="time (in days) after which the check must return a warning (RC-code = 1)", default=30)
    parser.add_argument("-c","--critical", type=int, help="time (in days) after which the check must return a critical (RC-code = 2)", default=14)
    args = parser.parse_args()


    req = requests.get(args.url)
    if req.status_code == 200:
        for line in req.text.split('\n'):
            match =  pattern_valid.match(line)
            if match:
                cert = ValidCert(
                    date=match.group('date'),
                    serial=match.group('serial'),
                    filename=match.group('filename'),
                    dn=match.group('dn'),
                )

    ok = ValidCert.get_valids()
    warn = ValidCert.get_warnings()
    crit = ValidCert.get_criticals()
    stdout = ''
    stdext = ''

    def display_certs(prefix: str, l: list) -> str:
        s = ''
        for i in l:
            s += "[{}] cn '{}' (serial {}) expire in {} days ({})\n".format(
                prefix,
                i.dn['CN'],
                i.serial,
                (i.validuntil - i._now).days,
                i.validuntil.isoformat()
            )
        return s

    if len(ok) > 0:
        rc_code = NAGIOS_RC_OK
        stdout += " - {} certificates OK".format(len(ok))
    if len(warn) > 0:
        rc_code = NAGIOS_RC_WARNING
        stdout += " - {} certificates to expire within {} days".format(len(warn), args.warning)
        stdext += display_certs('warning', warn)
    if len(crit) > 0:
        rc_code = NAGIOS_RC_CRITICAL
        stdout += " - {} certificates to expire within {} days".format(len(crit), args.critical)
        stdext += display_certs('critical', crit)

    print(NAGIOS_RC[rc_code] + stdout + "\n" + stdext)
    sys.exit(rc_code)
