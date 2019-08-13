Summary: Nagios plugins for RGM
Name: nagios-plugins-rgm
Version: 0.2
Release: 2.rgm
Source: %{name}-%{version}.tar.gz
Group: Applications/System
License: GPL

Requires: rgm-base nagios-plugins
Requires: coreutils, fping
Requires: python python-requests
Requires: perl perl-libwww-perl-old perl-LWP-Protocol-https perl-Mail-Sendmail perl-Module-Load perl-Nagios-Plugin perl-Time-Duration perl-WWW-Curl perl-Net-OpenSSH perl-IO-Tty

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
%defattr(0554, %{rgm_user_nagios}, %{rgm_group}, 0755)
%{rgmdatadir}
%{rgmdatadir}/*
%attr(0754,-,-) %{rgmdatadir}/aix/check_aix_errpt.sh
%attr(0754,-,-) %{rgmdatadir}/aix/check_aix_process2.pl
%attr(0754,-,-) %{rgmdatadir}/aix/check_aix_process.pl
%attr(0754,-,-) %{rgmdatadir}/aix/check_aix_swap
%attr(0754,-,-) %{rgmdatadir}/aix/check_snmp_HACMP.pl
%attr(0754,-,-) %{rgmdatadir}/as400/check_as400
%attr(0754,-,-) %{rgmdatadir}/as400/example/check_as400_dbf.php
%attr(0754,-,-) %{rgmdatadir}/as400/example/example.as400
%attr(0754,-,-) %{rgmdatadir}/as400/install.sh
%attr(0754,-,-) %{rgmdatadir}/backup/check_adic.pl
%attr(0754,-,-) %{rgmdatadir}/backup/check_dp_mediapool_size
%attr(0754,-,-) %{rgmdatadir}/backup/check_hycu_vm_backup.py
%attr(0754,-,-) %{rgmdatadir}/backup/check_logfiles
%attr(0754,-,-) %{rgmdatadir}/backup/check_Netbackup.py
%attr(0754,-,-) %{rgmdatadir}/backup/check_Netbackup.sh
%attr(0754,-,-) %{rgmdatadir}/backup/check_ts3500.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_db2_health
%attr(0754,-,-) %{rgmdatadir}/database/check_growth_mssql.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_mssql_health
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_bytes.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_connections
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_health
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_queries.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_slow.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_mysql_threads.pl
%attr(0754,-,-) %{rgmdatadir}/database/CheckOracleAlertLog.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_cloud_control.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_count
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_errorlogs.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_export_task.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_health
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_invalidobjects.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_log_alerts.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_rman_backups.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_sql.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_table_can_extend.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_oracle_tablespace.sh
%attr(0754,-,-) %{rgmdatadir}/database/check_pgsql
%attr(0754,-,-) %{rgmdatadir}/database/check_postgres.pl
%attr(0754,-,-) %{rgmdatadir}/database/check_sap_health
%attr(0754,-,-) %{rgmdatadir}/database/check_sqlbase_health
%attr(0754,-,-) %{rgmdatadir}/downtime/downtime_auto.sh
%attr(0754,-,-) %{rgmdatadir}/downtime/downtime_manual.sh
%attr(0754,-,-) %{rgmdatadir}/hardware/check_bmc_dell_raid
%attr(0754,-,-) %{rgmdatadir}/hardware/check_dell_bladechassis
%attr(0754,-,-) %{rgmdatadir}/hardware/check_dell_idrac7.pl
%attr(0754,-,-) %{rgmdatadir}/hardware/check_hp
%attr(0754,-,-) %{rgmdatadir}/hardware/check_hpasm
%attr(0754,-,-) %{rgmdatadir}/hardware/check_hp_bladechassis
%attr(0754,-,-) %{rgmdatadir}/hardware/check_hp_INSIGHT.sh
%attr(0754,-,-) %{rgmdatadir}/hardware/check_hp_raid_only
%attr(0754,-,-) %{rgmdatadir}/hardware/check_idrac_2.py
%attr(0754,-,-) %{rgmdatadir}/hardware/check_ilo_health.pl
%attr(0754,-,-) %{rgmdatadir}/hardware/check_msa_hardware.pl
%attr(0754,-,-) %{rgmdatadir}/hardware/check_om_chassis.pl
%attr(0754,-,-) %{rgmdatadir}/hardware/check_openmanage
%attr(0754,-,-) %{rgmdatadir}/hardware/check_pdu_health
%attr(0754,-,-) %{rgmdatadir}/hardware/check_PDU_health.pl
%attr(0754,-,-) %{rgmdatadir}/hardware/check_snmp_IBM_Bladecenter.pl
%attr(0754,-,-) %{rgmdatadir}/metricbeat/check_ELK_Values.pl
%attr(0754,-,-) %{rgmdatadir}/metricbeat/cpu.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/disk.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/interfaces.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/load.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/memory.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/process_nb.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/_rgmbeat.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/service_windows.py
%attr(0754,-,-) %{rgmdatadir}/metricbeat/uptime.py
%attr(0754,-,-) %{rgmdatadir}/nagios/check_bp_status.pl
%attr(0754,-,-) %{rgmdatadir}/nagios/check_eor_etl_end.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_eor_ods_load.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_eor_thruk_load.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_foxbox.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_gedevents.pl
%attr(0754,-,-) %{rgmdatadir}/nagios/check_gedevents.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_http_gearman.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_last_service_check.sh
%attr(0754,-,-) %{rgmdatadir}/nagios/check_remote_nagios_status.pl
%attr(0754,-,-) %{rgmdatadir}/nagios/event_generic.pl
%attr(0754,-,-) %{rgmdatadir}/nagios/pnp4n_send_host_mail.pl
%attr(0754,-,-) %{rgmdatadir}/nagios/pnp4n_send_service_mail.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_alvarion_antenne.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_APUpdateRequiered.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_aruba
%attr(0754,-,-) %{rgmdatadir}/network/check_asa_sessions.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_avaya_interface.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_avaya_load.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_avaya_vsp.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_Bonding.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_aironet_clients.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_asa.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_firewall.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_ips_cpu.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_ips.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_cisco_repstatus.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_CMT_juniper.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_dell_powerconnect
%attr(0754,-,-) %{rgmdatadir}/network/check_dell_powerconnect_M6220.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_fortigate.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_h3c_components.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_hirschmann_temp.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_int_traffic.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_ironport.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_lien_completel
%attr(0754,-,-) %{rgmdatadir}/network/check_line_OXE.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_linksys.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_linux_bonding
%attr(0754,-,-) %{rgmdatadir}/network/check_netscaler_certificat.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_netscaler_health.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_nwc_health
%attr(0754,-,-) %{rgmdatadir}/network/check-paloalto-A500.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_paloalto.py
%attr(0754,-,-) %{rgmdatadir}/network/check_pix_failover
%attr(0754,-,-) %{rgmdatadir}/network/check_pix_failover-v2.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_pix_vpn_sessions.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_proxy.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_radius
%attr(0754,-,-) %{rgmdatadir}/network/check_riverbed.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_riverbed_status.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_SDX_health.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_SDX_Instances.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_SDX_Services.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_avaya_8600_env.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_avaya.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_chkpfw.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_cpfw.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_ctrl_wifi_avaya.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_nortel_core
%attr(0754,-,-) %{rgmdatadir}/network/check_snmp_vrrp.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_squid.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_telnet.pl
%attr(0754,-,-) %{rgmdatadir}/network/check_test_avaya.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_TotalConnectedAP.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_TotalConnectionAPFailed.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_TotalManagedAP.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_trend.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_ucopia.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_VisimaxNVR.sh
%attr(0754,-,-) %{rgmdatadir}/network/check_wifi_essid.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_gedemat.sh
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_boostedge.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_cpfw.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_css_main.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_css.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_dell_equallogic_rgm.sh
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_env.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_FCports_brocade-v1.3.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_hpux_process.sh
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_IBM_Bladecenter.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_int.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_linkproof_nhr.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_load.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_mem.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_nsbox.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_process2.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_process.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_storage2.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_storage.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_synology
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_uptime.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_uptime.sh
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_vrrp.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/check_snmp_win.pl
%attr(0754,-,-) %{rgmdatadir}/snmp/monitoringplugin.py
%attr(0754,-,-) %{rgmdatadir}/storage/check_3PAR
%attr(0754,-,-) %{rgmdatadir}/storage/check_brocade_fcport_online.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_compellent
%attr(0754,-,-) %{rgmdatadir}/storage/check_compellent_alert.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_compellent_controller.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_compellent_volume.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_datacore.sh
%attr(0754,-,-) %{rgmdatadir}/storage/check_datadomain.sh
%attr(0754,-,-) %{rgmdatadir}/storage/check_dd.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_ds35xx.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_emc_clariion_2.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_emc_clariion_modif_dpe.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_emc_clariion.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_emc_trespass.ksh
%attr(0754,-,-) %{rgmdatadir}/storage/check_equallogic.sh
%attr(0754,-,-) %{rgmdatadir}/storage/check_eva.py
%attr(0754,-,-) %{rgmdatadir}/storage/check_FCBrocade_hardware.sh
%attr(0754,-,-) %{rgmdatadir}/storage/check_hpasm
%attr(0754,-,-) %{rgmdatadir}/storage/Check_Interface_NetApp.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_lefthand_cluster_vol.sh
%attr(0754,-,-) %{rgmdatadir}/storage/check_naf.py
%attr(0754,-,-) %{rgmdatadir}/storage/check_netapp3.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_netapp_cluster.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_netapp_sam.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_qnapdisk
%attr(0754,-,-) %{rgmdatadir}/storage/check_recoverpoint.pl
%attr(0754,-,-) %{rgmdatadir}/storage/check_snmp_syno.sh
%attr(0754,-,-) %{rgmdatadir}/storage/checkSolidFire.py
%attr(0754,-,-) %{rgmdatadir}/storage/check_vplex.sh
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/commands.py
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/hardwareCompStatus.py
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/serviceSetHealth.py
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/systemHealthCapacity.py
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/vtlStorageReport.py
%attr(0754,-,-) %{rgmdatadir}/storage/hpe_storeonce/vtlThroughputReport.py
%attr(0754,-,-) %{rgmdatadir}/system/check_apache_access.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_apt
%attr(0754,-,-) %{rgmdatadir}/system/check_arcgis_rest.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_ariba_tomcat.py
%attr(0754,-,-) %{rgmdatadir}/system/check_basicauth.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_Citrix_Director.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_Citrix_Licence.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_ControlM_Chain.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_ControlM_Chain_v2.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_CtrlM_Agent-2.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_flexlm
%attr(0754,-,-) %{rgmdatadir}/system/check_flexlm_licence_dat2.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_flexlm_licence_dat.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_flexlm_users.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_ftp
%attr(0754,-,-) %{rgmdatadir}/system/check_http_ntlm.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_jvm
%attr(0754,-,-) %{rgmdatadir}/system/check_nfs_export.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_nslookup.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_ntp_health
%attr(0754,-,-) %{rgmdatadir}/system/check_perf_process.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_printer_health
%attr(0754,-,-) %{rgmdatadir}/system/check_reverse_dns.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_sap_health
%attr(0754,-,-) %{rgmdatadir}/system/check_sharepoint.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_smb_share
%attr(0754,-,-) %{rgmdatadir}/system/check_smb_share_AA
%attr(0754,-,-) %{rgmdatadir}/system/check_smb_status.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_SpaceWalk-audit_scap.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_SpaceWalk-audit_scap_with_alert.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_ssh_custom.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_systime.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_tomcat.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_web_page_auth.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_web_page_file.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_web_page.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_web_site.sh
%attr(0754,-,-) %{rgmdatadir}/system/check_win_multiprocess.pl
%attr(0754,-,-) %{rgmdatadir}/system/check_zimbra.pl
%attr(0754,-,-) %{rgmdatadir}/system/Get_CtrlM_Agent_State.sh
%attr(0754,-,-) %{rgmdatadir}/system/get_flex_lic.sh
%attr(0754,-,-) %{rgmdatadir}/system/passive.sh
%attr(0754,-,-) %{rgmdatadir}/ups/check_mge_power_status.sh
%attr(0754,-,-) %{rgmdatadir}/ups/check_snmp_mgeeaton_ups.pl
%attr(0754,-,-) %{rgmdatadir}/ups/check_temp_mge_sensor.sh
%attr(0754,-,-) %{rgmdatadir}/ups/check_ups_apc.pl
%attr(0754,-,-) %{rgmdatadir}/ups/check_ups_health
%attr(0754,-,-) %{rgmdatadir}/ups/check_ups_snmp2.sh
%attr(0754,-,-) %{rgmdatadir}/virtu/check_esxi_hardware.py
%attr(0754,-,-) %{rgmdatadir}/virtu/check_HearBeat_Vcenter.sh
%attr(0754,-,-) %{rgmdatadir}/virtu/check_hyperv-health.sh
%attr(0754,-,-) %{rgmdatadir}/virtu/check_nutanix.pl
%attr(0754,-,-) %{rgmdatadir}/virtu/check_ssh_nutanix_cluster.pl
%attr(0754,-,-) %{rgmdatadir}/virtu/check_vmware_esx.pl
%attr(0754,-,-) %{rgmdatadir}/virtu/check_vmware.pl
%attr(0754,-,-) %{rgmdatadir}/windows/wmi/check_wmi_plus.pl

%changelog
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
