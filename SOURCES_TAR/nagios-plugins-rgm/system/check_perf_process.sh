Perf_CPU=hrSWRunPerfCPU
Perf_MEM=hrSWRunPerfMem
NAME_Process=hrSWRunName
PATH_Process=hrSWRunPath
ARG_Process=hrSWRunParameters

Index=`snmpwalk -v2c -c $2 $1 hrSWRunName | grep $3 | cut -d'.' -f2 | cut -d' ' -f1`
Cpu=`snmpwalk -v2c -c $2 $1 $Perf_CPU | grep $Perf_CPU.$Index | awk '{ print $4 }'`
Mem=`snmpwalk -v2c -c $2 $1 $Perf_MEM | grep $Perf_MEM.$Index | awk '{ print $4 }'`

echo $Index $Cpu $Mem

