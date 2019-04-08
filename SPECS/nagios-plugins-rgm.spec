Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 0.2
Release: 0.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL

Requires: rgm-base nagios-plugins
Requires: coreutils, fping
Requires: python python-requests
Requires: perl perl-libwww-perl-old perl-LWP-Protocol-https perl-Mail-Sendmail perl-Module-Load perl-Nagios-Plugin perl-Time-Duration

BuildRequires: rpm-macros-rgm autoconf automake gawk perl


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


#BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildRoot: /tmp/test

Source1: metricbeat
Source2: network
Source3: check_nwc_health-7.6.tar.gz


%define	rgmdatadir		%{rgm_path}/lib/%{name}-%{version}

%description
Collection of Nagios plugins for RGM
Currently includes Nagios metricbeat plugins for ElasticSearch/metricbeat


%prep
%setup -q
%setup -D -a 3

%build

# build check_nwc_health
cd check_nwc_health-7.6
./configure --libexecdir=%{rgmdatadir}/network --with-nagios-user=%{rgm_user_nagios} --with-nagios-group=%{rgm_group}
make

%install

# copy contrib & metricbeat plugins
install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}
cp -afv %{SOURCE1} %{buildroot}%{rgmdatadir}/

# install check_nwc_health
install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}/network
install -m 0755 -o %{rgm_user_nagios} -g %{rgm_group} check_nwc_health-7.6/plugins-scripts/check_nwc_health %{buildroot}%{rgmdatadir}/network/

%post
ln -s %rgmdatadir "$(rpm -ql nagios | grep 'plugins$')/rgm"

%preun
rm -f "$(rpm -ql nagios | grep 'plugins$')/rgm"

%clean
#rm -rf %{buildroot}


%files
%defattr(0644, %{rgm_user_nagios}, %{rgm_group}, 0755)
%{rgmdatadir}
%{rgmdatadir}/metricbeat
%{rgmdatadir}/metricbeat/*
%attr(0754,%{rgm_user_nagios},%{rgm_group}) %{rgmdatadir}/metricbeat/*.py


%changelog
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
