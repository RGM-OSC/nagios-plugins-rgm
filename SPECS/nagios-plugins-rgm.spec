Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 1.0
Release: 34.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL

Requires: rgm-base nagios-plugins
Requires: coreutils, fping
Requires: python python-requests
Requires: python-rgm >= 1.0-4
Requires: perl perl-libwww-perl-old perl-LWP-Protocol-https perl-Mail-Sendmail perl-Module-Load perl-Nagios-Plugin perl-Time-Duration perl-WWW-Curl perl-Net-OpenSSH perl-IO-Tty perl-Number-Format perl-DateTime perl-IPC-Cmd perl-Filesys-SmbClient
Requires: wget bc wmi

BuildRequires: rpm-macros-rgm autoconf automake gawk perl

AutoReqProv: 0

# disable debuginfo package build
%define debug_package %{nil}

### Consol.Labs plugins
# https://labs.consol.de/assets/downloads/nagios/

%define check_nwc_health     check_nwc_health-7.10.0.6
%define check_db2_health     check_db2_health-1.1.2.2
%define check_mssql_health   check_mssql_health-2.6.4.14
%define check_oracle_health  check_oracle_health-3.1.2.2
%define check_sap_health     check_sap_health-2.0.0.5
%define check_sqlbase_health check_sqlbase_health-1.0.0.2
%define check_mysql_health   check_mysql_health-3.0.0.5
%define check_hpasm          check_hpasm-4.8
%define check_ups_health     check_ups_health-2.8.3.3
%define check_logfiles       check_logfiles-3.11.0.2
%define check_ntp_health     check_ntp_health-1.3
%define check_pdu_health     check_pdu_health-2.4
%define check_printer_health check_printer_health-1.0.1.1


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source1: %{check_nwc_health}.tar.gz
Source2: %{check_db2_health}.tar.gz
Source3: %{check_mssql_health}.tar.gz
Source4: %{check_oracle_health}.tar.gz
Source5: %{check_sap_health}.tar.gz
Source6: %{check_sqlbase_health}.tar.gz
Source7: %{check_mysql_health}.tar.gz
Source8: %{check_hpasm}.tar.gz
Source9: %{check_ups_health}.tar.gz
Source10: %{check_logfiles}.tar.gz
Source11: %{check_ntp_health}.tar.gz
Source12: %{check_pdu_health}.tar.gz
Source13: %{check_printer_health}.tar.gz
Source14: snmp2elastic.tar.gz

%define	rgmdatadir		%{rgm_path}/lib/%{name}-%{version}

# force rpmbuild to byte-compile using Python3
%global __python %{__python3}


%description
Collection of Nagios plugins for RGM
Currently includes Nagios metricbeat plugins for ElasticSearch/metricbeat


%prep
%setup -q -n %{name}
%setup -D -a 1 -n %{name}
%setup -D -a 2 -n %{name}
%setup -D -a 3 -n %{name}
%setup -D -a 4 -n %{name}
%setup -D -a 5 -n %{name}
%setup -D -a 6 -n %{name}
%setup -D -a 7 -n %{name}
%setup -D -a 8 -n %{name}
%setup -D -a 9 -n %{name}
%setup -D -a 10 -n %{name}
%setup -D -a 11 -n %{name}
%setup -D -a 12 -n %{name}
%setup -D -a 13 -n %{name}
%setup -D -a 14 -n %{name}


%build

# build Consol.Labs plugins
cd %{check_nwc_health}
./configure --libexecdir=%{rgmdatadir}/network --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_db2_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_mssql_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_oracle_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_sap_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_sqlbase_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_mysql_health}
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_hpasm}
./configure --libexecdir=%{rgmdatadir}/storage --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_ups_health}
./configure --libexecdir=%{rgmdatadir}/ups --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_logfiles}
./configure --libexecdir=%{rgmdatadir}/backup --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_ntp_health}
./configure --libexecdir=%{rgmdatadir}/system --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_pdu_health}
./configure --libexecdir=%{rgmdatadir}/hardware --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../%{check_printer_health}
./configure --libexecdir=%{rgmdatadir}/system --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make

%install

# copy contrib & metricbeat plugins
install -d -m 0755 %{buildroot}%{rgmdatadir}
cp -afv aix %{buildroot}%{rgmdatadir}/
cp -afv as400 %{buildroot}%{rgmdatadir}/
cp -afv apache %{buildroot}%{rgmdatadir}/
cp -afv azure %{buildroot}%{rgmdatadir}/
cp -afv backup %{buildroot}%{rgmdatadir}/
cp -afv business %{buildroot}%{rgmdatadir}/
cp -afv citrix %{buildroot}%{rgmdatadir}/
cp -afv database %{buildroot}%{rgmdatadir}/
cp -afv downtime %{buildroot}%{rgmdatadir}/
cp -afv hardware %{buildroot}%{rgmdatadir}/
cp -afv metricbeat %{buildroot}%{rgmdatadir}/
cp -afv MIBS %{buildroot}%{rgmdatadir}/
cp -afv nagios %{buildroot}%{rgmdatadir}/
cp -afv network %{buildroot}%{rgmdatadir}/
cp -afv pki %{buildroot}%{rgmdatadir}/
cp -afv prometheus %{buildroot}%{rgmdatadir}/
cp -afv snmp %{buildroot}%{rgmdatadir}/
cp -afv storage %{buildroot}%{rgmdatadir}/
cp -afv system %{buildroot}%{rgmdatadir}/
cp -afv ups %{buildroot}%{rgmdatadir}/
cp -afv virtu %{buildroot}%{rgmdatadir}/
cp -afv windows %{buildroot}%{rgmdatadir}/

install -Dm 0400 sudoers/nagios_teleport %{buildroot}%{_sysconfdir}/sudoers.d/nagios_teleport

# install Consol.Labs plugins
install -d -m 0755 %{buildroot}%{rgmdatadir}/network
install -d -m 0755 %{buildroot}%{rgmdatadir}/database
install -m 0755 %{check_nwc_health}/plugins-scripts/check_nwc_health %{buildroot}%{rgmdatadir}/network/
install -m 0755 %{check_db2_health}/plugins-scripts/check_db2_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_mssql_health}/plugins-scripts/check_mssql_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_oracle_health}/plugins-scripts/check_oracle_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_sap_health}/plugins-scripts/check_sap_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_sqlbase_health}/plugins-scripts/check_sqlbase_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_mysql_health}/plugins-scripts/check_mysql_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 %{check_hpasm}/plugins-scripts/check_hpasm %{buildroot}%{rgmdatadir}/storage/
install -m 0755 %{check_ups_health}/plugins-scripts/check_ups_health %{buildroot}%{rgmdatadir}/ups/
install -m 0755 %{check_logfiles}/plugins-scripts/check_logfiles %{buildroot}%{rgmdatadir}/backup/
install -m 0755 %{check_ntp_health}/plugins-scripts/check_ntp_health %{buildroot}%{rgmdatadir}/system/
install -m 0755 %{check_pdu_health}/plugins-scripts/check_pdu_health %{buildroot}%{rgmdatadir}/hardware/
install -m 0755 %{check_printer_health}/plugins-scripts/check_printer_health %{buildroot}%{rgmdatadir}/system/

# install snmp2elastic plugin
install -m 0755 snmp2elastic/nagios_checks/check_el_nwc.py %{buildroot}%{rgmdatadir}/network/

# ignore rpmbuild python policy script RC at the end of install
exit 0


%post
LINKTARGET="$(rpm -ql nagios | grep 'plugins$')/rgm"
if [ -e "$LINKTARGET" ] && [ -L "$LINKTARGET" ] ; then
    rm -f "$LINKTARGET"
fi
ln -s %rgmdatadir "$LINKTARGET"


%postun
# will it remain a package after uninstall ?
# $1 == 0 in case of complete uninstallation,
# $1 > 0 in case of package upgrade
if [ "$1" = 0 ]; then
    LINKTARGET="$(rpm -ql nagios | grep 'plugins$')/rgm"
    if [ -e "$LINKTARGET" ]; then
        rm -f "$(rpm -ql nagios | grep 'plugins$')/rgm"
    fi
fi


%clean
rm -rf %{buildroot}

%files
%defattr(0754, %{rgm_user_nagios}, %{rgm_group}, 0755)
%{rgmdatadir}
%config %attr(0400,root,root) %{_sysconfdir}/sudoers.d/nagios_teleport


%changelog
* Tue Mar 28 2023 Alex Rocher <arocher@fr.scc.com> - 1.0-32.rgm
- Fix source name

* Mon Mar 27 2023 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-32.rgm
- fix teleport check to report OK when teleport is disabled

* Tue Jan 3 2023 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-31.rgm
- add cadvisor check
- add prometheus node_exporter checks for cpu, fs, memory, uptime
- add Azure cloud services
- add Citrix Cloud sessions
- add ged/stargate check

* Tue Dec 13 2022 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-30.rgm
- update ES interfaces check: add nic name filter (pattern/regex/invert)

* Wed Aug 03 2022 Alex Rocher <arocher@fr.scc.com> - 1.0-29.rgm
- Add generic service check for metricbeat (linux by default)

* Wed Jul 06 2022 Christophe Cassan <ccassan@fr.scc.com> - 1.0-28.rgm
- Add azure checks part 1

* Wed Jan 19 2022 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-27.rgm
- add check_pki_index check for OpenSSL PKI index

* Wed Sep 15 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-26.rgm
- fix RGM business check certificate (OCSP URL)

* Wed Sep 15 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-25.rgm
- add RGM business check certificate
- add RGM business teleport check

* Mon Jul 26 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-24.rgm
- disk: ignore overlay and squashfs FS mountpoints on Linux
- process_nb: fix argument processing when no warn or crit parameters provided

* Mon Jul 19 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-23.rgm
- fix ES uptime perfdata output

* Mon Jun 07 2021 Michael Aubertin <maubertin@fr.scc.com> - 1.0-22.rgm
- Update to comply Vmware SDK compliant.

* Mon Mar 22 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-21.rgm
- add --exclude filter mode on disk.py elastic check
- fix interfaces.py query parameter for ES 7.10 - backward compatible with ES 7.3

* Fri Jan 15 2021 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-20.rgm
- add patch provided by V. Fricou :
  add provisioned storage on check_vmware_esx.pl

* Tue Nov 03 2020 Lucas Fueyo <lfueyo@fr.scc.com> - 1.0-19.rgm
- add check_veeam_jobs in backup checks
- add check_wmi_veeam_licence in backup checks

* Wed Oct 28 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-18.rgm
- fix SPEC file for correct package upgrade
- fix display typo on metricbeat disk check in verbose mode
- rename check_oracle_health check_oracle_health_rgm to avoid conflict with upstream ConsolLab check

* Thu Oct 22 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-17.rgm
- metricbeat systime.py check addition: check system time through metricbeat
- add check-netapp-ng.pl in storage checks

* Thu Oct 15 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-16.rgm
- metricbeat disk.py check enhancements:
  - add mountpoint filtering features on metricbeat disk.py check
  - add verbose levels for Nagios output text
  - add storage unit autodetection (or force specific unit)

* Fri Jun 26 2020 Lucas Fueyo <lfueyo@fr.scc.com> - 1.0.15.rgm
- Add clearpass checks

* Thu Jun 25 2020 Vincent Fricou <vincent@fricouv.eu> - 1.0-14.rgm
- Add check_dd6300 for EMC DataDomain 6300
- Add check_snmp_compellent for Dell Compellent

* Fri Jun 19 2020 Lucas Fueyo <lfueyo@fr.scc.com> - 1.0-13.rgm
- Add new containers check

* Thu Jun 18 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-12.rgm
- fix spec file issues

* Wed Feb 04 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-11.rgm
- fix path for check_bp_status

* Thu Jan 30 2020 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-10.rgm
- package Java JMX check

* Wed Jan 08 2020 Michael Aubertin <maubertin@fr.scc.com> - 1.0-9.rgm
- Add new Oracle check

* Wed Jan 08 2020 Michael Aubertin <maubertin@fr.scc.com> - 1.0-8.rgm
- Update WMI plugins

* Tue Jan 07 2020 Michael Aubertin <maubertin@fr.scc.com> - 1.0-7.rgm
- Comment urllib3 packages warning usage in disk.py

* Tue Oct 29 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-6.rgm
- add snmp2elastic nagios plugin (CASA dev)

* Thu Oct 03 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-5.rgm
- upgrade ConsolLabs plugin check_nwc_health to version 7.10.0.6

* Mon Sep 30 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 1.0-4.rgm
- fix argument type casting to int for warning, critical, timeout on metricbeat checks

* Fri Sep 27 2019 Michael Aubertin <maubertin@fr.scc.com> - 1.0-3.rgm
- Change Apache check

* Fri Sep 27 2019 Michael Aubertin <maubertin@fr.scc.com> - 1.0-2.rgm
- Add Apache Status Check

* Fri Sep 27 2019 Michael Aubertin <maubertin@fr.scc.com> - 1.0-1.rgm
- Fix git merge issue

* Fri Sep 27 2019 Michael Aubertin <maubertin@fr.scc.com> - 1.0-0.rgm
- First RGM release.

* Tue Aug 13 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.2-2.rgm
- update files attrs

* Fri Apr 26 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.2-1.rgm
- add Perl dependencies: perl-Net-OpenSSH perl-IO-Tty

* Mon Apr 08 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.2-0.rgm
- imported contrib plugins

* Fri Apr 05 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.1.2.rgm
- rewrite of disk.py elastic check
- initial write of interfaces.py elastic plugin

* Tue Mar 26 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.1.1.rgm
- code factorization & mutualization
- add elastichost cmd line argument

* Mon Mar 25 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.1.0.rgm
- initial release
