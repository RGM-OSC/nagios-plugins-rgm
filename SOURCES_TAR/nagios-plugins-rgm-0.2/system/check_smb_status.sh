#!/bin/bash
#
#    Program : check_smb_status
#            :
#    Purpose : Nagios plugin to return the number of user/processes into a smb
#            : server, total machines connected and the number of files open.
#            :
# Parameters : --help
#            : --version
#            :
#    Returns : Standard Nagios status_* codes as defined in utils.sh
#            :
#      Notes :
#============:==============================================================
#        1.0 : may/08/2011
#
PROGPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.0 $' | sed -e 's/[^0-9.]//g'`

SMBSTATUS_P="/tmp/smbstatus_p"
SMBSTATUS_L="/tmp/smbstatus_L"
/usr/bin/smbstatus -p > $SMBSTATUS_P 2> /dev/null
/usr/bin/smbstatus -L > $SMBSTATUS_L 2> /dev/null



. $PROGPATH/utils.sh

print_usage() {
        echo "Usage: $PROGNAME --help"
        echo "Usage: $PROGNAME --version"
}

print_help() {
        print_revision $PROGNAME $REVISION
        echo ""
        print_usage
        echo ""
        echo "Samba status check."
        echo ""
        support
}


if [ $# -gt 1 ]; then
        print_usage
        exit $STATE_UNKNOWN
fi


exitstatus=$STATE_WARNING
while test -n "$1"; do
        case "$1" in
                --help)
                        print_help
                        exit $STATE_OK
                        ;;
                -h)
                        print_help
                        exit $STATE_OK
                        ;;
                --version)
                        print_revision $PROGNAME $REVISION
                        exit $STATE_OK
                        ;;
                -V)
                        print_revision $PROGNAME $REVISION
                        exit $STATE_OK
                        ;;

                *)
                        echo "Unknown argument: $1"
                        print_usage
                        exit $STATE_UNKNOWN
                        ;;
        esac
        shift
done

total_usersProcess=$(egrep "^([0-9]| +[0-9])" $SMBSTATUS_P | wc -l)

total_files=$(egrep "^([0-9]| +[0-9])" $SMBSTATUS_L | wc -l)

total_machines=$(egrep "^([0-9]| +[0-9])" $SMBSTATUS_P | awk '{print $5}' | sort -u | wc -l)


echo "Total Users/Process:$total_usersProcess Total Machines:$total_machines Total Files:$total_files  |Total Users/Process=$total_usersProcess Total Machines=$total_machines Total Files=$total_files"

rm -f $SMBSTATUS_P $SMBSTATUS_L

exit $STATE_OK
