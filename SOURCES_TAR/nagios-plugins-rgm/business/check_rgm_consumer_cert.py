#!/srv/rgm/python-rgm/bin/python3

import sys, configparser, subprocess
from datetime import datetime
from cryptography import x509
from cryptography.hazmat.backends import default_backend

ocspurl = None
cert, issuer = None, None
subj_cn, subj_ou, subj_contact = '', '', ''

yumrepo = configparser.ConfigParser()
yumrepo.read('/etc/yum.repos.d/rgm.repo')
certfile = yumrepo['rgm-business-base']['sslclientcert']
with open(certfile, 'rb') as f:
    cert = x509.load_pem_x509_certificate(f.read(), default_backend())

issuerfile = "/etc/pki/ca-trust/source/anchors/{}.crt".format(
    cert.issuer.get_attributes_for_oid(x509.name.NameOID.COMMON_NAME)[0].value.lower().replace(' ', '_')
)
with open(issuerfile, 'rb') as f:
    issuer = x509.load_pem_x509_certificate(f.read(), default_backend())

subj_cn = cert.subject.get_attributes_for_oid(x509.name.NameOID.COMMON_NAME)[0].value
subj_ou = cert.subject.get_attributes_for_oid(x509.name.NameOID.ORGANIZATIONAL_UNIT_NAME)[0].value
subj_contact = cert.subject.get_attributes_for_oid(x509.name.NameOID.EMAIL_ADDRESS)[0].value

now = datetime.now()
if now < cert.not_valid_before or now > cert.not_valid_after:
    print(
        "CRITICAL: Certificate validity expired - not valid before: {} - not valid after: {}".format(
            cert.not_valid_before.strftime("%Y/%m/%d %H:%M:%S"),
            cert.not_valid_after.strftime("%Y/%m/%d %H:%M:%S")
        )
    )
    sys.exit(2)

for ext in cert.extensions.get_extension_for_oid(x509.oid.ExtensionOID.AUTHORITY_INFORMATION_ACCESS).value:
    if ext.access_method.dotted_string == '1.3.6.1.5.5.7.48.1':
        ocspurl = ext.access_location.value
        ocsp = subprocess.run(
            [
                '/usr/bin/openssl',
                'ocsp',
                '-issuer',
                issuerfile,
                '-cert',
                certfile,
                '-url',
                ocspurl,
                '-header',
                'Host',
                "{}".format(ocspurl.split('/')[-1])
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        if ocsp.returncode != 0:
            print("CRITICAL: OCSP status failed for '{}' () - Please contact <{}>".format(subj_ou, subj_cn, subj_contact))
            sys.exit(2)
        else:
            print("OK: OCSP status valid for '{}' ({})".format(subj_ou, subj_cn))
            sys.exit(0)

print("WARNING: Unable to check OCSP status for '{}' ({})".format(subj_ou, subj_cn))
sys.exit(1)

