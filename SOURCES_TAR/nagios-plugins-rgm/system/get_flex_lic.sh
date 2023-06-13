#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

for line in $(/srv/eyesofnetwork/nagios/plugins/lmutil lmdiag -n -c $1 | /bin/sed '/^$/d' | /usr/bin/tr '\n' ' ' | /bin/sed 's/\(--\)/\n\1/g' | /bin/sed '/^--$/d' | /bin/sed 's:^--- ::g' | /bin/sed -e 's:"::g' | /usr/bin/awk '{print $1" "$11" "$12" "$13}' | /bin/sed '/^lmutil Reserved/d' | /bin/sed '/^License/d' | /bin/sed 's/,$//g' | /bin/sed 's/ date This$//g' | /bin/sed 's/ This license$//g' | /bin/sed 's:,::g' | /bin/sed 's: date Requests::g' | /bin/sed -e 's: :�:g'); do
    serv="$(echo $line | /bin/cut -d'�' -f1)"
    exp_date="$(echo $line | /bin/cut -d'�' -f2)"
    if [ -n "$(echo $line | /bin/grep expiration)" ]; then
       echo "$serv expiration" | /bin/sed -e 's:�::g'
       continue;
    fi
    if [ -n "$(echo $line | /bin/grep expires)" ]; then
       exp_date="$(echo $line | /bin/cut -d':' -f2)"

       # 2038 but handleling on 32bit platform
       exp_year="$(echo $exp_date | /bin/cut -d'-' -f3)"
       if [ $exp_year -gt 2038 ]; then
           exp_date="01-jan-2037"
       fi

       echo "$serv $exp_date" | /bin/sed -e 's:�::g'
       continue;
    fi
    echo "$serv $exp_date" | /bin/sed -e 's:�::g'
done

