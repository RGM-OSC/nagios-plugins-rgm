Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 1.0
Release: 4.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL

Requires: rgm-base nagios-plugins
Requires: coreutils, fping
Requires: python python-requests
Requires: perl perl-libwww-perl-old perl-LWP-Protocol-https perl-Mail-Sendmail perl-Module-Load perl-Nagios-Plugin perl-Time-Duration perl-WWW-Curl perl-Net-OpenSSH perl-IO-Tty wget bc

BuildRequires: rpm-macros-rgm autoconf automake gawk perl

AutoReqProv:   0


### Consol.Labs plugins
# https://labs.consol.de/assets/downloads/nagios/check_db2_health-1.1.2.2.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_hpasm-4.8.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_logfiles-3.11.0.2.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_mailbox_health-1.7.2.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_mssql_health-2.6.4.14.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_ntp_health-1.3.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_nwc_health-7.6.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_oracle_health-3.1.2.2.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_pdu_health-2.4.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_printer_health-1.0.1.1.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_sap_health-2.0.0.5.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_sqlbase_health-1.0.0.2.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_ups_health-2.8.3.3.tar.gz
# https://labs.consol.de/assets/downloads/nagios/check_mysql_health-3.0.0.5.tar.gz


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source1: check_nwc_health-7.6.tar.gz
Source2: check_db2_health-1.1.2.2.tar.gz
Source3: check_mssql_health-2.6.4.14.tar.gz
Source4: check_oracle_health-3.1.2.2.tar.gz
Source5: check_sap_health-2.0.0.5.tar.gz
Source6: check_sqlbase_health-1.0.0.2.tar.gz
Source7: check_mysql_health-3.0.0.5.tar.gz
Source8: check_hpasm-4.8.tar.gz
Source9: check_ups_health-2.8.3.3.tar.gz
Source10: check_logfiles-3.11.0.2.tar.gz
Source11: check_ntp_health-1.3.tar.gz
Source12: check_pdu_health-2.4.tar.gz
Source13: check_printer_health-1.0.1.1.tar.gz

%define	rgmdatadir		%{rgm_path}/lib/%{name}-%{version}

%description
Collection of Nagios plugins for RGM
Currently includes Nagios metricbeat plugins for ElasticSearch/metricbeat


%prep
%setup -q
%setup -D -a 1
%setup -D -a 2
%setup -D -a 3
%setup -D -a 4
%setup -D -a 5
%setup -D -a 6
%setup -D -a 7
%setup -D -a 8
%setup -D -a 9
%setup -D -a 10
%setup -D -a 11
%setup -D -a 12
%setup -D -a 13


%build

# build Consol.Labs plugins
cd check_nwc_health-7.6
./configure --libexecdir=%{rgmdatadir}/network --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_db2_health-1.1.2.2
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_mssql_health-2.6.4.14
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_oracle_health-3.1.2.2
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_sap_health-2.0.0.5
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_sqlbase_health-1.0.0.2
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_mysql_health-3.0.0.5
./configure --libexecdir=%{rgmdatadir}/database --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_hpasm-4.8
./configure --libexecdir=%{rgmdatadir}/storage --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_ups_health-2.8.3.3
./configure --libexecdir=%{rgmdatadir}/ups --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_logfiles-3.11.0.2
./configure --libexecdir=%{rgmdatadir}/backup --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_ntp_health-1.3
./configure --libexecdir=%{rgmdatadir}/system --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_pdu_health-2.4
./configure --libexecdir=%{rgmdatadir}/hardware --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make
cd ../check_printer_health-1.0.1.1
./configure --libexecdir=%{rgmdatadir}/system --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group} && make


%install

# copy contrib & metricbeat plugins
install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}
cp -afv aix %{buildroot}%{rgmdatadir}/
cp -afv as400 %{buildroot}%{rgmdatadir}/
cp -afv apache %{buildroot}%{rgmdatadir}/
cp -afv backup %{buildroot}%{rgmdatadir}/
cp -afv database %{buildroot}%{rgmdatadir}/
cp -afv downtime %{buildroot}%{rgmdatadir}/
cp -afv hardware %{buildroot}%{rgmdatadir}/
cp -afv metricbeat %{buildroot}%{rgmdatadir}/
cp -afv MIBS %{buildroot}%{rgmdatadir}/
cp -afv nagios %{buildroot}%{rgmdatadir}/
cp -afv network %{buildroot}%{rgmdatadir}/
cp -afv snmp %{buildroot}%{rgmdatadir}/
cp -afv storage %{buildroot}%{rgmdatadir}/
cp -afv system %{buildroot}%{rgmdatadir}/
cp -afv ups %{buildroot}%{rgmdatadir}/
cp -afv virtu %{buildroot}%{rgmdatadir}/
cp -afv windows %{buildroot}%{rgmdatadir}/

# install Consol.Labs plugins
install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}/network
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_nwc_health-7.6/plugins-scripts/check_nwc_health %{buildroot}%{rgmdatadir}/network/
install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}/database
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_db2_health-1.1.2.2/plugins-scripts/check_db2_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_mssql_health-2.6.4.14/plugins-scripts/check_mssql_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_oracle_health-3.1.2.2/plugins-scripts/check_oracle_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_sap_health-2.0.0.5/plugins-scripts/check_sap_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_sqlbase_health-1.0.0.2/plugins-scripts/check_sqlbase_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_mysql_health-3.0.0.5/plugins-scripts/check_mysql_health %{buildroot}%{rgmdatadir}/database/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_hpasm-4.8/plugins-scripts/check_hpasm %{buildroot}%{rgmdatadir}/storage/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_ups_health-2.8.3.3/plugins-scripts/check_ups_health %{buildroot}%{rgmdatadir}/ups/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_logfiles-3.11.0.2/plugins-scripts/check_logfiles %{buildroot}%{rgmdatadir}/backup/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_ntp_health-1.3/plugins-scripts/check_ntp_health %{buildroot}%{rgmdatadir}/system/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_pdu_health-2.4/plugins-scripts/check_pdu_health %{buildroot}%{rgmdatadir}/hardware/
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_printer_health-1.0.1.1/plugins-scripts/check_printer_health %{buildroot}%{rgmdatadir}/system/


%post
ln -s %rgmdatadir "$(rpm -ql nagios | grep 'plugins$')/rgm"

%preun
rm -f "$(rpm -ql nagios | grep 'plugins$')/rgm"

%clean
#rm -rf %{buildroot}


%files
%defattr(0754, %{rgm_user_nagios}, %{rgm_group}, 0755)
%{rgmdatadir}


%changelog
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
