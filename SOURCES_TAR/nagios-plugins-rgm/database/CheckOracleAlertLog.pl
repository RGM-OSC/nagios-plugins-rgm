#!/usr/bin/perl -w
# *************************************************************************************************
#                                                           EB le 23/05/2016
# Execution
# -----------------------------------
# Recherche dans un fichier de type alerte log Oracle les chaines ORA-xxxxx
# Attend en parametre -h <host> avec host un nom de base
# Retour :
#   - OK si fichier vide         : OK - No error Oracle detected, file empty
#   - OK si pas de ORA-xxxx      : OK - No error Oracle detected
#   - Warning si ORA-xxxx trouve : Warning - %5d error(s) Oracle detected (last : %-8s), %s, %s
# *************************************************************************************************
#
# Modifications
# -------------
#  2016-05-23  EB      En cas de Warning, affichage des 20 premieres lignes dans le retour
#  2016-05-23  EB      Recherche de ORA-\d* au lieu de ORA-[0-9]{1,5}
#
# *************************************************************************************************

# *************************************************************************************************
#  Fonctions
# *************************************************************************************************
use strict;
use DateTime;

my $option=shift;
my $base=shift;
my $lbase=lc($base);

if (! (defined ($option) &&  defined ($base) &&  $option eq "-h")){
 printf "ERROR - Bad parameters\n";
 exit 3;
}

my $repFic="/home/mco_ora_maub/mco/RecupAlertLog/fic/";
my $fichier="${repFic}*_$base.ora.log ${repFic}*_$lbase.ora.log";
my $delta=24;
my $nagios_level=3;
my @erreurs;

my @ficT=glob($fichier);
my $fic=$ficT[0];

if ( defined($fic) && ! -z $fic ) {
 open(FIC,"<$fic") or die("open: $!");
 my $l;
 my $nb=0;
 my $dl;
 my $ld;
 my $le="";
 my $fd="";
 my $fc='^[A-Z][a-z]{2} ([A-Z][a-z]{2})  ?([0-9]{1,2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) ([0-9]{4})$';
 my $dt=DateTime->now();
 $dt->set_time_zone( 'Europe/Paris' );
 my $dc=DateTime->now();
 $dc=$dc->subtract(hours=>$delta);
 my $ok=0;
 my %months = ("Jan"=>"01","Feb"=>"02","Mar"=>"03","Apr"=>"04","May"=>"05","Jun"=>"06","Jul"=>"07","Aug"=>"08","Sep"=>"09","Oct"=>"10","Nov"=>"11","Dec"=>"12");
 while( defined( $l = <FIC> ) ) {
  chomp $l;
  $dl=$l if ($l =~ m/$fc/);
  if ($l =~ m/(ORA-\d*)/){
   $le=$1;
   if ($dl =~ m/$fc/){
    $dt->set(year=> $6,month=>$months{$1},day=> $2,hour=> $3,minute=> $4,second=>$5);
    if ($dt > $dc){
     $nb++;
     $ld=$dl;
     $fd=$dl if ($fd eq "");
     unshift(@erreurs,$2."/".$months{$1}."/".$6." ".$3.":".$4.":".$5." ".$l."\n");
    }
   }
  }
 }
 if ($nb > 0) {
  printf "Warning - %5d error(s) Oracle detected (last : %-8s), %s, %s\n", $nb, $le, $fd, $ld;
  my $numLigne=0;
  foreach my $ligne (@erreurs) {
   $numLigne++;
   print "$ligne" if ($numLigne < 20);
  }
  $nagios_level=1;
 } else {
  printf "OK - No error Oracle detected\n";
  $nagios_level=0;
 }
} else {
 printf "OK - No error Oracle detected, file empty\n";
 $nagios_level=0;
}

exit $nagios_level;

