#!/usr/bin/python

import os, time, sys
from math import ceil

if len(sys.argv) <2:
        print "Usage: check_Netbackup.py $hostname $information_check\n"
        print "For information about $information_check use check_Solaris.py information."
        sys.exit(1)

if sys.argv[1] == "information":
        print "Options available for $information_check is:\n- DB"
        sys.exit(1)

path = "/tmp/tmp-internal-Solaris/infos_solaris/" + sys.argv[1] + "_SendInfoToEon.txt"

date_of_file = os.path.getmtime(path)
actually_date = time.time()

warning_time = 60 * 6
critical_time = 60 * 10

if (actually_date - critical_time) > date_of_file:
        print('CRITICAL, date of file is too old')
        sys.exit(2)

elif (actually_date - warning_time) > date_of_file:
        print('WARNING, date of file is too old')
        sys.exit(1)

with open(path, 'r') as file:
        line = file.readlines()

for element in line:
        value = element.split(' ')
        if value[0] == sys.argv[2] or value[-1][:-1] == sys.argv[2]:
                value_list = []

                #CheckDB#
                if value[0] == 'DB':
                        state = value[1]
                        if state != 'ok\n':
                                print "CRITICAL, Netbackup Database is not Alive!"
                                sys.exit(2)
                        out_string = "Netbackup DB is Alive!"

			print 'OK, ', out_string
			sys.exit(0)

