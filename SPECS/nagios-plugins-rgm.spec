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

BuildRequires: rpm-macros-rgm


BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source1: metricbeat

%define	rgmdatadir		%{rgm_path}/lib/%{name}-%{version}

%description
Collection of Nagios plugins for RGM
Currently includes Nagios metricbeat plugins for ElasticSearch/metricbeat


%prep
%setup -q

%build

%install

install -d -o %{rgm_user_nagios} -g %{rgm_group} -m 0755 %{buildroot}%{rgmdatadir}

cp -afv %{SOURCE1} %{buildroot}%{rgmdatadir}/

%post
ln -s %rgmdatadir "$(rpm -ql nagios | grep 'plugins$')/rgm"

%preun
rm -f "$(rpm -ql nagios | grep 'plugins$')/rgm"

%clean
rm -rf %{buildroot}


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