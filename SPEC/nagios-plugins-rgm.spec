Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 0.1
Release: 0.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL
Requires: rgm-base nagios
REquires: metricbeat
BuildRequires: rpm-macros-rgm

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source1: schema.sql
Source2: httpd-rgmweb.conf

%define	rgmdatadir		%{rgm_path}/%{name}-%{version}
%define rgmlinkdir		%{rgm_path}/%{name}

%description
Collection of Nagios plugins for RGM


