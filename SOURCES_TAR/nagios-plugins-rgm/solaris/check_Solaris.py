#!/usr/bin/python

import os, time, sys
from math import ceil

if len(sys.argv) <2:
        print "Usage: check_Solaris.py $hostname $information_check ($warning) ($critical)\nThe threshold is not use for all checks\n"
        print "For information about $information_check and threshold use check_Solaris.py information."
        sys.exit(1)

if sys.argv[1] == "information":
        print "Options available for $information_check is:\n- SolarisCheckLog (without threshold)\n- SolarisCheckVALSYS (without threshold)\n- SolarisCheckUpTime (without threshold)\n- SolarisCheckNBUClient (without threshold)\n- SolarisCheckPluginOST (without threshold)\n- SolarisCheckFault (without threshold)\n- SolarisCheckZone (without threshold)\n- SolarisCheckProc (with threshold)\n- SolarisCheckCPU (with threshold)\n- SolarisCheckCPUZone (with thresold)\n- SolarisCheckLoadAverage (with threshold)\n- SolarisCheckMEM (with threshold)\n- SolarisCheckZombie (with threshold)\n\nFor check FS use name of FS instead of $information_check; ex: /tmp"
        sys.exit(1)

if len(sys.argv) <3:
        print "Usage: check_Solaris.py $hostname $information_check ($warning) ($critical)\nThe threshold is not use for all checks\n"
        print "For information about $information_check and threshold use check_Solaris.py information."
        sys.exit(1)

path = "/tmp/tmp-internal-Solaris/infos_solaris/" + sys.argv[1] + "_SendInfoToEon.txt"

#date_of_file =time.strftime("%d-%m-%Y %H:%M:%S", time.gmtime(os.path.getmtime(path)))

#actually_date = time.strftime("%d-%m-%Y %H:%M:%S", time.gmtime(time.time()))

date_of_file = os.path.getmtime(path)
actually_date = time.time()

warning_time = 60 * 6
critical_time = 60 * 10

checks_list = ['SolarisCheckLog','SolarisCheckVALSYS','SolarisCheckUpTime','SolarisCheckNBUClient','SolarisCheckFault','SolarisCheckZone','SolarisCheckConditionCTM','SolarisCheckWAS','SolarisCheckNISPLUS','SolarisCheckAggregat','SolarisCheckPluginOST','SolarisCheckPeripheralDD9500']

if sys.argv[2] == 'SolarisCheckAllProcess' and len(sys.argv) < 4:
        print "Name process is require with ", sys.argv[2]
        sys.exit(1)

elif sys.argv[2] == 'SolarisCheckAllProcess' and len(sys.argv) >= 4:
	pass

elif sys.argv[2] == 'SolarisCheckPeripheralDD9500' and len(sys.argv) == 4:
	pass

elif sys.argv[2] in checks_list and len(sys.argv) >3:
	print "Don't use threshold with ", sys.argv[2]
	sys.exit(1)

elif sys.argv[2] not in checks_list and len(sys.argv) !=5:
	print "Use threshold with ", sys.argv[2]
        sys.exit(1)

elif sys.argv[2] not in checks_list and len(sys.argv) ==5:
	warning = sys.argv[3]
	critical = sys.argv[4]

	if int(warning) >= int(critical):
		print "Warning thresold is greater than or equal to critical thresold"
		sys.exit(1)


if (actually_date - critical_time) > date_of_file:
	print('CRITICAL, date of file is too old')
	sys.exit(2)

elif (actually_date - warning_time) > date_of_file:
	print('WARNING, date of file is too old')
        sys.exit(1)

with open(path, 'r') as file:
	line = file.readlines()

#On initialise la variable compteur de processus pour le check SolarisCheckAllProcess
nb_process = 0

for element in line:
	value = element.split(' ')
	if value[0] == sys.argv[2] or value[-1][:-1] == sys.argv[2]:
		value_list = []
	
		#Check_Log#
                if value[0] == 'SolarisCheckLog':
                        log = value[1:]
			log = " ".join(log)
                        if log != 'ok\n':
                                out_string = "Log details: " + log[:-1]
                                print 'CRITICAL, ', out_string
                                sys.exit(2)
                        out_string = 'No error in log.'
		
		#error system#
                elif value[0] == 'SolarisCheckVALSYS':
                        for part in value[1:]:
                                if part == '':
                                        pass
                                else:
                                        value_list.append(part)

                        graph = value_list[1] + "=" + value_list[0] + " " + value_list[3] + "=" + value_list[2] + " " + value_list[5] + "=" + value_list[4]
                        out_string = "Click on for details\nName: " + value_list[1] + ", Value: " + value_list[0] + "\nName: " + value_list[3] + ", Value: " + value_list[2] + "\nName: " + value_list[5] + ", Value: " + value_list[4] + "|" + graph
	
		#Check Uptime#
                elif value[0] == 'SolarisCheckUpTime':
                        for part in value[1:]:
                                if part == '':
                                        pass
                                else:
                                        value_list.append(part)

                        out_string = "boot time : " + value_list[0] + " " + value_list[1] + " " + value_list[2][:-1]

		#Check NBU process#
		elif value[0] == 'SolarisCheckNBUClient':
                        for part in value[1:]:
                               	value_list.append(part)

			bpcd = value_list[0]
			if len(value_list) == 1:
				vnetd = '\n'
			else:
				vnetd = value_list[1]

                        out_string = "NBU client communication"

                        if bpcd == "" and vnetd == "\n":
                               	print "CRITICAL Click for details\n" + out_string + " bpcd,vnetd port not open\nPlease run /usr/openv/netbackup/bin/vnetd -standalone\n/usr/openv/netbackup/bin/bpcd -standalone"
                               	sys.exit(2)
                        elif bpcd == "":
                               	print "CRITICAL Click for details\n" + out_string + " bpcd port not open\nPlease run /usr/openv/netbackup/bin/bpcd -standalone"
                               	sys.exit(2)

                        elif vnetd == "" or vnetd == "\n":
                               	print "CRITICAL Click for details\n" + out_string + " vnetd port not open\nPlease run /usr/openv/netbackup/bin/vnetd -standalone"
                               	sys.exit(2)

                #Check System Fault#
                elif value[0] == 'SolarisCheckFault':
                        fault = value[1][:-1]

                        if fault != 'nothing':
                                out_string = "Please run cmd `fmadm faulty -a` for more information and `fmadm faulty -s` for view error no acquited. When error is repair, please run `fmadm acquit $EVENT-ID` where EVENT-ID is available in fmadm command"

                                print "CRITICAL, ", out_string
                                sys.exit(2)
                        else:
                                out_string = "No fault in system."

		#Check zone solaris#
                elif value[0] == 'SolarisCheckZone':
                        nb_zone = int(value[1])
                        name_zones = value[2:]
			name_zones = ",".join(name_zones)

                        nb_zone_in_EON = int(os.popen('/bin/grep -e ' + sys.argv[1] + "$ /srv/eyesofnetwork/nagios/etc/objects/hosts.cfg | /bin/grep -Ev 'host_name|display_name|alias' | /usr/bin/wc -l").read())

			graph = "nb_zone=" + str(nb_zone)

                        out_string = "Click on for details\n" + name_zones[:-1] + "|" + graph

                        if nb_zone > nb_zone_in_EON:
                                print 'CRITICAL, all virtuals hosts not running, ' + out_string
                                sys.exit(2)

		#Check consommation process#
		elif value[0] == 'SolarisCheckProc':
			for part in value[1:]:
				if part == '':
					pass
				else:
					value_list.append(part)

			out_string = "Process: " + value_list[3][:-1] + ", PID: " + value_list[2] + ", cons: CPU: " + value_list[0] + "%" + ", MEM: " + value_list[1] + "%"

			if int(critical) < int(value_list[0]) or int(critical) < int(value_list[1]):
				print 'CRITICAL ', out_string
				sys.exit(2)
			elif int(warning) < int(value_list[0]) or int(warning) < int(value_list[1]):
                                print 'WARNING ', out_string
                                sys.exit(1)
		
		#Check process available#
		elif value[0] == 'SolarisCheckAllProcess':
			process = " ".join(value[1:])
			if sys.argv[3] in process:
				nb_process += 1
				continue
			else:
				continue

		#Check consommation CPU#
		elif value[0] == 'SolarisCheckCPU':
			for part in value[1:]:
                                if part == '':
                                        pass
                                else:
                                        value_list.append(part)

			cons_cpu = 100 - float(value_list[0])
			graph = " cpu=" + str(cons_cpu) + "%;" + warning + ";" + critical + ";0"
			out_string = "CPU used: " + str(cons_cpu) + "%" + "|" + graph

			if int(critical) < cons_cpu:
                                print 'CRITICAL ', out_string
                                sys.exit(2)
                        elif int(warning) < cons_cpu:
                                print 'WARNING ', out_string
                                sys.exit(1)

		elif value[0] == 'SolarisCheckCPUZone':
			out_string = ""
			graph = ""
			flag = 0
			error = "OK"
			#la liste contient un espace. le nombre de zones a l'index 2
			zone_names = value[3:int(value[2]) +3]

			index = value.index('ZONE') +1
			value = value[index:-1]

			for name in zone_names:
				if name in value:
					continue
				value.append('0.0%')
				value.append(name)

                        for part in value:
				if part[-1] == '%':
					cpu_used = float(part[:-1])

					if cpu_used >= critical:
						flag = 2
						error = "CRITICAL"
					elif cpu_used >= warning:
						if flag == 2:
							pass
						else:
							flag = 1
							error = "WARNING"

					out_string = out_string + 'CPU used: ' + str(cpu_used) +'%'
				else:
					server_name = part
					out_string = out_string + ', Server: ' + server_name + '\n'
					zone_cpu = str(value[value.index(server_name) -1])
					graph = graph + " cpu_" + server_name + "=" + zone_cpu + ";" + warning + ";" + critical + ";0"

			print error + "," + out_string + "|" + graph
			sys.exit(flag)

		#check load average#
		elif value[0] == 'SolarisCheckLoadAverage':
			for part in value[1:]:
                                if part == '':
                                        pass
                                else:
					value_list.append(part)

			if len(value_list) < 3:
				print "No return from output uptime command on Solaris server."
                                sys.exit(0)

			graph = " LoadAverage=" + value_list[0][:-1] + ";" + warning + ";" + critical + ";0"
        		out_string = "Load average: " + value_list[0] + value_list[1] + value_list[2] + "|" + graph

        		if float(value_list[0][:-1]) >= int(critical):
                		print 'CRITICAL ', out_string
                		sys.exit(2)

        		elif float(value_list[0][:-1]) >= int(warning):
                		print 'WARNING ', out_string
                		sys.exit(1)

		#check Memory and SWAP#
		elif value[0] == 'SolarisCheckMEM':
                        for part in value[1:]:
                                if part == '':
                                        pass
                                else:
                                        value_list.append(part)
			
			mem_free = ceil((int(value_list[0]) *8) /1024.)
			mem_total = int(value_list[1])
			mem_use = mem_total - mem_free
			mem_percent = ceil((mem_use *100) / mem_total)

			swap_use = ceil(int(value_list[2][:-1]) /1024.)
			swap_free = ceil(int(value_list[3][:-2]) /1024.)
			swap_total = swap_use + swap_free
			swap_percent = ceil((swap_use *100) / float(swap_total))
			warning_swap = int(warning) /1.5
			critical_swap = int(critical) /1.5

			graph = " memory=" + str(mem_use) + "MB;" + warning + ";" + critical + ";0 swap=" + str(swap_use) + "MB;" + str(warning_swap) + ";" + str(critical_swap) + ";0"

			out_string = "Memory: " + str(mem_percent) + '% ('+ str(mem_use) + "M/" + str(mem_total) + "M), Swap: " + str(swap_percent) + '% (' + str(swap_use) + "M/" + str(swap_total) + "M) |" + graph

			if mem_percent >= int(critical) or swap_percent >= int(critical_swap):
				print 'CRITICAL ', out_string
                                sys.exit(2)

			elif mem_percent >= int(warning) or swap_percent >= int(warning_swap):
				print 'WARNING ', out_string
                                sys.exit(1)

		#Check Zombie process#
		elif value[0] == 'SolarisCheckZombie':
			nb_zombie = int(value[1])

			graph = "zombie=" + str(nb_zombie) + ";" + warning + ";" + critical + ";0"

			if nb_zombie == 0:
                		out_string = "No Zombie process find |" + graph
        
			elif nb_zombie < int(warning):
				pid = value[2:]
				pid = ", ".join(pid)
                		out_string = "Some Zombie process find, click for detail\n PID: " + pid + " | " + graph
        		elif nb_zombie >= int(critical):
                		out_string = "Lots of Zombie process find, kill the following processes (PID)"
				pid = value[2:]
				pid = ", ".join(pid)
                		print "CRITICAL, ", out_string, "\nPID: ", pid, " | ", graph
                		#sys.exit(2)
				sys.exit(0)
        
			else:
                		out_string = "Several Zombie process find, kill the following processes (PID)"
				pid = value[2:]
				pid = ", ".join(pid)
                		print "WARNING, ", out_string, "\nPID: ", pid, " | " + graph
                		#sys.exit(1)
				sys.exit(0)

		#Check Condition EC2 CTM
		elif value[0] == 'SolarisCheckConditionCTM':
			condition = value[1][:-1]
			if condition == "ok":
				out_string = "La condition EC2 est presente"
				print out_string
				sys.exit(0)
			elif condition == "nok":
				out_string = "CRITICAL, La condition EC2 n'est pas presente"
				os.popen("/srv/eyesofnetwork/nagios/plugins/Downtime/downtime_manual.sh downtime_service vermont 900 admin 'Condition EC2 non presente. Downtime positionne sur le check_SAPjob' check_SAPjob")
				os.popen("/srv/eyesofnetwork/nagios/plugins/Downtime/downtime_manual.sh downtime_service ControlM 900 admin 'Condition EC2 non presente. Downtime positionne sur le BP ControlM PRD' ControlM_PRD")
				print out_string
				sys.exit(1)

		#Check Log WAS Application
		elif value[0] == 'SolarisCheckWAS':
			result = value[1][:-1]
			if result == "ok":
				out_string = "WAS Application started"
			else:
				print "CRITICAL, WAS Application not started"
				sys.exit(1)

		#Check size file mprv.dat for TIMEPORT(hapy)
		elif value[0] == 'SolarisTIMEPORT':
			size = int(value[1][:-1])
			out_string = "size file mprv.dat: "+ str(ceil(size/1000000)) + "MB"
			if size >= int(critical):
				print "CRITICAL, ", out_string
				sys.exit(2)
			elif size >= int(warning):
                                print "WARNING, ", out_string
                                sys.exit(1)
			elif size < int(warning):
				graph = "mprv.dat" + "=" + str(ceil(size /1000000)) + "MB;"+ str(ceil(int(warning) /1000000)) + ";" + str(ceil(int(critical) /1000000)) + ";0"
				out_string = "size file mprv.dat: " + str(ceil(size/1000000)) + "MB |" + graph

		#Check NIS+ MASTER
		elif value[0] == 'SolarisCheckNISPLUS':
                        ret_code = int(value[1][:-1])
			if int(ret_code) == 0:
				out_string = "Master NIS+ available."
			else:
				out_string = "CRITICAL, Master NIS+ not available."
				print out_string
				sys.exit(2)

		#Check Aggregat
		elif value[0] == 'SolarisCheckAggregat':
			print ' '.join(value[1:])

			if value[1][0:-1] == "CRITICAL":
				sys.exit(2)
			else:
				sys.exit(0)

		#Check Plugin OST (Netbackup media-server)
		elif value[0] == 'SolarisCheckPluginOST':
			if int(value[1]) == 0:
				out_string = "Plugin OST loaded"
			else:
				out_string = "CRITICAL, Plugin OST not loaded"
				sys.exit(2)

		#Check Peripherals DD9500 (Netbackup media-server)
		elif value[0] == 'SolarisCheckPeripheralDD9500':
			for part in value:
				if part == '':
					pass
				else:
					nb = part[0:-1]
			if int(nb) == int(sys.argv[3]):
				out_string = "all peripherals present (%s)" % sys.argv[3]
        		else:
                		print "CRITICAL, %s peripherals present instead of %s" % (nb, sys.argv[3])
                		sys.exit(2)

		#Check FS#
		elif value[-1][:-1] == sys.argv[2]:
                        for part in value:
                                if part == '':
                                        pass
                                else:
                                        value_list.append(part)

			fs_name = value_list[-1][:-1]
			used = int(value_list[2])
			available = int(value_list[3])
			size = used + available
			percent = value_list[4]

                        graph = " " + fs_name + "=" + str(ceil(used /1000)) + "MB;" + warning + ";" + critical + ";0 " + fs_name + "_percent=" + percent + ";" + warning + ";" + critical + ";0"

                        out_string = fs_name + ": " + percent + "used (" + str(ceil(used /1000)) + "MB/" + str(ceil(size /1000)) + "MB) : |" + graph

                        if (int(value_list[1]) * int(critical)) /100 <= int(value_list[2]):
                                print 'CRITICAL ', out_string
                                sys.exit(2)

                        elif (int(value_list[1]) * int(warning)) /100 <= int(value_list[2]):
                                print 'WARNING ', out_string
                                sys.exit(1)

		print 'OK,', out_string
                sys.exit(0)

#Si le process n'est pas trouve on sort en erreur ici.
if sys.argv[2] == 'SolarisCheckAllProcess':
        if nb_process == 0:
                print 'CRITICAL, process', sys.argv[3], "not available"
                sys.exit(2)
        try:
		if nb_process > int(sys.argv[5]):
			print "CRITICAL, too many processes :", nb_process, "process", sys.argv[3], ">", sys.argv[5]
			sys.exit(2)
		elif nb_process > int(sys.argv[4]):
                        print "WARNING, too many processes :", nb_process, "process", sys.argv[3], ">", sys.argv[4]
			sys.exit(2)
		else:
			print "OK,", nb_process, "Process " + sys.argv[3] + " UP"
                        sys.exit(0)
	except IndexError:
		print "OK,", nb_process, "Process " + sys.argv[3] + " UP"
                sys.exit(0)
