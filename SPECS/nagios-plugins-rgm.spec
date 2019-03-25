Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 0.1
Release: 0.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL

Requires: rgm-base nagios
Requires: metricbeat
Requires: python python-requests

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
* Mon Mar 25 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.1.0.rgm
- initial release