Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 0.1
Release: 0.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL
Requires: rgm-base nagios
Requires: metricbeat
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
install -d -o root -g %{rgm_group} -m 0775 %{buildroot}%{rgmdocdir}

cp -afv metricbeat %{buildroot}%{rgmdatadir}/

%post
ln -s %rgmdatadir "$(rpm -ql nagios | grep 'plugins$')/%{name}"

%clean
rm -rf %{buildroot}


%files
%defattr(-, %{rgm_user_nagios}, %{rgm_group}, 0644)
%attr(0755,%{rgm_user_nagios},%{rgm_group}) %{rgmdatadir}
%attr(0755,%{rgm_user_nagios},%{rgm_group}) %{rgmdatadir}/metricbeat
%attr(0754,%{rgm_user_nagios},%{rgm_group}) %{rgmdatadir}/metricbeat/*.py
%attr(0644,%{rgm_user_nagios},%{rgm_group}) %{rgmdatadir}/metricbeat/*.md


%changelog
* Mon Mar 25 2019 Eric Belhomme <ebelhomme@fr.scc.com> - 0.1.0.rgm
- initial release