#!/usr/bin/env perl
sub cluster_list_vm_volumes_info
{
        my ($cluster, $blacklist) = @_;

        my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {name => "$cluster"}, properties => ['name', 'datastore']);

        if (!defined($cluster_view->datastore))
           {
           print "Insufficient rights to access Datastores on the Host\n";
           exit 2;
           }

        return datastore_volumes_info($cluster_view->datastore, $subselect, $blacklist);
}

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub datastore_volumes_info
    {
    my ($datastore) = @_;
    my $state = 0;
    my $actual_state = 0;
    my $output = '';
    my $tmp_output = '';
    my $tmp_output_error = '';
    my $space_total;
    my $space_total_MB;
    my $space_total_GB;
    my $space_total_percent;
    my $space_free;
    my $space_free_MB;
    my $space_free_GB;
    my $space_free_percent;
    my $space_used;
    my $space_used_MB;
    my $space_used_GB;
    my $space_used_percent;
    my $tmp_warning = $warning;
    my $tmp_critical = $critical;
    my $warn_out;
    my $crit_out;
    my $ref_store;
    my $store;
    my $name;
    my $volume_type;
    my $uom = "MB";
    my $alertcnt = 0;
       
    if (defined($subselect) && defined($blacklist) && !defined($isregexp))
       {
       print "Error! Blacklist is supported only in overall check (no subselect) or regexp subcheck!\n";
       exit 2;
       }

    if (defined($subselect) && defined($whitelist) && !defined($isregexp))
       {
       print "Error! Whitelist is supported only in overall check (no subselect) or regexp subcheck!\n";
       exit 2;
       }
    
    if (!defined($usedspace) && defined($perf_free_space))
       {
       print "Error! --perf_free_space only allowed in conjuction with --usedspace!\n";
       exit 2;
       }

    if (defined($isregexp))
       {
       $isregexp = 1;
       }
    else
       {
       $isregexp = 0;
       }
               
    foreach $ref_store (@{$datastore})
            {
            $store = Vim::get_view(mo_ref => $ref_store, properties => ['summary', 'info']);

            $name = $store->summary->name;
            $volume_type = $store->summary->type;

            if (!defined($subselect) || ($name eq $subselect) || (($isregexp == 1) && ($name =~ m/$subselect/)))
               {
               
               if (defined($blacklist))
                  {
                  if (isblacklisted(\$blacklist, $isregexp, $name ))
                     {
                     next;
                     }
                  }

               if (defined($whitelist))
                  {
                  if (isnotwhitelisted(\$whitelist, $isregexp, $name))
                     {
                     next;
                     }
                  }

               if ((!defined($blacklist)) && (!defined($blacklist)) && ((defined($subselect) && $name !~ m/$subselect/)))
                  {
                  next;
                  }

               if ($store->summary->accessible)
                  {
                  $space_total = $store->summary->capacity;
                  $space_free = $store->summary->freeSpace;
                  $space_used = $space_total - $space_free;
                  $space_used_percent = simplify_number(100 * $space_used/ $space_total);
                  $space_free_percent = 100 - $space_used_percent;

                  if ($gigabyte)
                     {
                     $space_total_GB = simplify_number($space_total / 1024 / 1024 / 1024);
                     $space_free_GB = simplify_number($space_free / 1024 / 1024 / 1024);
                     $space_used_GB = simplify_number($space_used / 1024 / 1024 / 1024);
                     $uom = "GB";
                     }
                  else
                     {
                     $space_total_MB = simplify_number($space_total / 1024 / 1024);
                     $space_free_MB = simplify_number($space_free / 1024 / 1024);
                     $space_used_MB = simplify_number($space_used / 1024 / 1024);
                     }

                  if (defined($warning) || defined($critical))
                     {
                     if (!(defined($warning) && defined($critical)))
                        {
                        print "For checking thresholds on volumes you MUST specify threshols for warning AND critical. Otherwise it is not possible";
                        print " to determine whether you are checking for used or free space!\n";
                        exit 2;
                        }
                     }
                  if (defined($warning) && defined($critical))
                     {
                     if ($usedspace)
                        {
                        if (!defined($subselect))
                           {
                           if ((!($warn_is_percent)) && (!($crit_is_percent)))
                              {
                              if (!(defined($spaceleft)))
                                 {
                                 print "On multiple volumes setting warning or critical threshold is only allowed";
                                 print " in percent for used space or --spaceleft must be used.\n";
                                 exit 2;
                                 }
                              else
                                 {
                                 if ($gigabyte)
                                    {
                                    $warning = $space_total_GB - $tmp_warning;
                                    $critical = $space_total_GB - $tmp_critical;
                                    }
                                 else
                                    {
                                    $warning = $space_total_MB - $tmp_warning;
                                    $critical = $space_total_MB - $tmp_critical;
                                    }
                                 }
                              }
                           }
                        }
                     }
                     
                  if (($warn_is_percent) || ($crit_is_percent))
                     {
                     if ($usedspace)
                        {
                        $actual_state = check_against_threshold($space_used_percent);
                        $state = check_state($state, $actual_state);
                        }
                     else
                        {
                        $actual_state = check_against_threshold($space_free_percent);
                        $state = check_state($state, $actual_state);
                        }
                     if ( $actual_state > 0 )
                        {
                        $alertcnt++;
                        }
                     }
                  else
                     {
                     if ($usedspace)
                        {
                        if ($gigabyte)
                           {
                           $actual_state = check_against_threshold($space_used_GB);
                           $state = check_state($state, $actual_state);
                           }
                        else
                           {
                           $actual_state = check_against_threshold($space_used_MB);
                           $state = check_state($state, $actual_state);
                           }
                        }
                     else
                        {
                        if ($gigabyte)
                           {
                           $actual_state = check_against_threshold($space_free_GB);
                           $state = check_state($state, $actual_state);
                           }
                        else
                           {
                           $actual_state = check_against_threshold($space_free_MB);
                           $state = check_state($state, $actual_state);
                           }
                        }
                     if ( $actual_state > 0 )
                        {
                        $alertcnt++;
                        }
                     }

                  if ($gigabyte)
                     {
                     $space_total = $space_total_GB;
                     $space_free = $space_free_GB;
                     $space_used = $space_used_GB;
                     }
                  else
                     {
                     $space_total = $space_total_MB;
                     $space_free = $space_free_MB;
                     $space_used = $space_used_MB;
                     }

                  if (($warn_is_percent) || ($crit_is_percent))
                     {
                     if (defined($perf_free_space))
                        {
                        $warn_out =  $space_total / 100 * (100 - $warning);
                        $crit_out =  $space_total / 100 * (100 - $critical);
                        }
                     else
                        {
                        $warn_out =  $space_total / 100 * $warning;
                        $crit_out =  $space_total / 100 * $critical;
                        }
                     $warn_out =  sprintf "%.2f", $warn_out;
                     $crit_out =  sprintf "%.2f", $crit_out;
                     $perf_thresholds = $warn_out . ";" . $crit_out;
                     }

                  if (defined($usedspace) && (!defined($perf_free_space)))
                     {
                     $perfdata = $perfdata . " \'" . $name . "\'=" . $space_used . "$uom;" . $perf_thresholds . ";;" . $space_total;
                     }
                  else
                     {
                     $perfdata = $perfdata . " \'" . $name . "\'=" . $space_free . "$uom;" . $perf_thresholds . ";;" . $space_total;
                     }

                  if ($actual_state != 0)
                     {
                     $tmp_output_error = $tmp_output_error . "$name ($volume_type)" . ($usedspace ? " used" : " free");
                     $tmp_output_error = $tmp_output_error . ": ". ($usedspace ? $space_used : $space_free) . " " . $uom;
                     $tmp_output_error = $tmp_output_error . " (" . ($usedspace ? $space_used_percent : $space_free_percent) . "%) / $space_total $uom (100%)";
                     $tmp_output_error = $tmp_output_error . $multiline;
                     }
                  else
                     {
                     $tmp_output = $tmp_output . "$name ($volume_type)" . ($usedspace ? " used" : " free");
                     $tmp_output = $tmp_output . ": ". ($usedspace ? $space_used : $space_free) . " " . $uom;
                     $tmp_output = $tmp_output . " (" . ($usedspace ? $space_used_percent : $space_free_percent) . "%) / $space_total $uom (100%)";
                     $tmp_output = $tmp_output . $multiline;
                     }
                  }
               else
                  {
                  $state = 2;
                  $tmp_output_error = $tmp_output_error . "'$name' is not accessible, ";
                  $alertcnt++;
                  }
            
               if (!$isregexp && defined($subselect) && ($name eq $subselect))
                  {
                  last;
                  }
               }
            }

    if (defined($warning) && defined($critical))
       {
       if ($alertonly)
          {
          $output = "Volumes above thresholds:" . $multiline;
          $output = $output . $tmp_output_error;
          }
       else
          {
          $output = "Volumes above thresholds:" . $multiline;
          $output = $output . $tmp_output_error;
          $output = $output . "------------------------------------------------" . $multiline;
          $output = $output . "Volumes below thresholds:" . $multiline;
          $output = $output . $tmp_output;
          }
       }
    else
       {
       $output = $tmp_output;
       }

    if ($output)
       {
       if ( $state == 0 )
          {
          $output = "OK for selected volume(s)." . $multiline . $output;
          }
       else
          {
          if ($alertonly)
             {
             if (($warn_is_percent) || ($crit_is_percent))
                {
                $output = $alertcnt . " alert(s) for some of the selected volume(s) (warn:" . $warning . "%,crit:" . $critical . "%)" . $multiline . $output;
                }
             else
                {
                $output = $alertcnt . " alert(s) for some of the selected volume(s) (warn:" . $warning . ",crit:" . $critical . ")" . $multiline . $output;
                }
             }
          else
             {
             if (($warn_is_percent) || ($crit_is_percent))
                {
                $output = $alertcnt . " alert(s) found for some of the selected volume(s) (warn:" . $warning . "%,crit:" . $critical . "%)" . $multiline . $output;
                }
             else
                {
                $output = $alertcnt . " alert(s) found for some of the selected volume(s) (warn:" . $warning . ",crit:" . $critical . ")" . $multiline . $output;
                }
             }
          }
       }
    else
       {
       if ($alertonly)
          {
          $output = "OK. There are no alerts";
          }
       else
          {
          $state = 1;
          $output = defined($subselect)?$isregexp? "No matching volumes for regexp \"$subselect\" found":"No volume named \"$subselect\" found":"There are no volumes";
          }
       }
       return ($state, $output);
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub dc_list_vm_volumes_info
    {
    my $dc_views;
    my @datastores;
    my $dc;

    $dc_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['datastore']);
    
    if (!defined($dc_views))
       {
       print "There are no Datacenter\n";
       exit 2;
       }

    foreach $dc (@$dc_views)
            {
            if (defined($dc->datastore))
               {
               push(@datastores, @{$dc->datastore});
               }
            }

    return datastore_volumes_info(\@datastores);
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub dc_runtime_info
    {
    my $state = 0;
    my $actual_state;
    my $output = '';
    my $tmp_output = '';
    my $issue_out = '';
    my $runtime;
    my $host_views;
    my $host_state;
    my $host;
    my $dc_views;
    my $dc;
    my $overallStatus;
    my $issues;
    my $issue_cnt = 0;
    my $issues_ignored_cnt = 0;
    my $poweredon = 0;           # Virtual machine powerstate counter
    my $poweredoff = 0;          # Virtual machine powerstate counter
    my $suspended = 0;           # Virtual machine powerstate counter
    my $poweredon_out = '';      # Virtual machine powerstate temporary output
    my $poweredoff_out = '';     # Virtual machine powerstate temporary output
    my $suspended_out = '';      # Virtual machine powerstate temporary output
    my $hpoweredon = 0;          # VMware ESX host powerstate counter
    my $hpoweredoff = 0;         # VMware ESX host powerstate counter
    my $hpoweredon_out = '';     # VMware ESX host powerstate temporary output
    my $hpoweredoff_out = '';    # VMware ESX host powerstate temporary output
    my $vm;
    my $vm_state;
    my $vm_views;
    my $vm_cnt = 0;
    my $vm_bad_cnt = 0;      
    my $vm_ignored_cnt = 0;       
    my $guestToolsBlacklisted_cnt = 0;
    my $guestToolsCurrent_cnt = 0;
    my $guestToolsNeedUpgrade_cnt = 0;
    my $guestToolsSupportedNew_cnt = 0;
    my $guestToolsSupportedOld_cnt = 0;
    my $guestToolsTooNew_cnt = 0;
    my $guestToolsTooOld_cnt = 0;
    my $guestToolsUnmanaged_cnt = 0;
    my $guestToolsUnknown_cnt = 0;
    my $guestToolsNotRunning_cnt = 0;
    my $guestToolsNotInstalled_cnt = 0;
    my $guestToolsPOF_cnt = 0;
    my $guestToolsSuspendePOF_cnt = 0;
    my $vm_guest;
    my $tools_out = '';
    my $cluster;
    my $cluster_state;
    my $cluster_views;
    my $cluster_gray_cnt = 0;    # Cluster gray state counter
    my $cluster_green_cnt = 0;   # Cluster green state counter
    my $cluster_red_cnt = 0;     # Cluster red state counter
    my $cluster_yellow_cnt = 0;  # Cluster yellow state counter
    my $cluster_gray_out = '';   # Cluster gray temporary output
    my $cluster_green_out = '';  # Cluster green temporary output
    my $cluster_red_out = '';    # Cluster red temporary output
    my $cluster_yellow_out = ''; # Cluster yellow temporary output

    my $vc_gray_cnt = 0;         # Vcenter gray state counter
    my $vc_green_cnt = 0;        # Vcenter green state counter
    my $vc_red_cnt = 0;          # Vcenter red state counter
    my $vc_yellow_cnt = 0;       # Vcenter yellow state counter
    my $vc_name;

    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ( $perf_thresholds ne ";")
          {
          print "Error! Thresholds are only allowed with subselects but ";
          print "not with --subselect=health !\n";
          exit 2;
          }
       }


    if (($subselect eq "listvms") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       my %vm_state_strings = ("poweredOn" => "UP", "poweredOff" => "DOWN", "suspended" => "SUSPENDED");
       $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name', 'runtime']);

       if (!defined($vm_views))
          {
          print "Runtime error\n";
          exit 2;
          }
       
       if (!@$vm_views)
          {
          $output = "No VMs";
          }
       else
          {
          foreach $vm (@$vm_views)
                  {
                  if (defined($isregexp))
                     {
                     $isregexp = 1;
                     }
                  else
                     {
                     $isregexp = 0;
                     }
               
                  if (defined($blacklist))
                     {
                     if (isblacklisted(\$blacklist, $isregexp, $vm->name))
                        {
                        next;
                        }
                     }
                  if (defined($whitelist))
                     {
                     if (isnotwhitelisted(\$whitelist, $isregexp, $vm->name))
                        {
                        next;
                        }
                      }

                  $vm_state = $vm->runtime->powerState->val;
               
                  if ($vm_state eq "poweredOn")
                     {
                     $poweredon++;
                     if (!$alertonly)
                        {
                        $poweredon_out = $poweredon_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                        }
                     }
                  if ($vm_state eq "poweredOff")
                     {
                     $poweredoff++;
                     $poweredoff_out = $poweredoff_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                     }
                  if ($vm_state eq "suspended")
                     {
                     $suspended++;
                     $suspended_out = $suspended_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                     }
                  }

          if ($subselect eq "all")
             {
             $output = $suspended . "/" . @$vm_views . " VMs suspended - ";
             $output = $output . $poweredoff . "/" . @$vm_views . " VMs powered off - ";
             $output = $output . $poweredon . "/" . @$vm_views . " VMs powered on";
             }
          else
             {
             $output = $suspended . "/" . @$vm_views . " VMs suspended - ";
             $output = $output . $poweredoff . "/" . @$vm_views . " VMs powered off - ";
             $output = $output . $poweredon . "/" . @$vm_views . " VMs powered on." . $multiline;
             $output = $output . $suspended_out . $poweredoff_out . $poweredon_out;
             $perfdata = "\'vms_total\'=" .  @$vm_views . ";;;; \'vms_poweredon\'=" . $poweredon . ";;;; \'vms_poweredoff\'=" . $poweredoff . ";;;; \'vms_suspended\'=" . $suspended . ";;;;";
             }
          }
       }


    if (($subselect eq "listhost") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name', 'runtime.powerState']);

       if (!defined($host_views))
          {
          print "Runtime error\n";
          exit 2;
          }

       if (!@$host_views)
          {
          if ($subselect eq "all")
             {
             $output = $output . " - No VMware ESX hosts";
             }
          else
             {
             $output = "No VMware ESX hosts.";
             $state = 2;
             }
          }
       else
          {
          foreach $host (@$host_views)
                  {
                  $host->update_view_data(['name', 'runtime.powerState']);

                  if (defined($isregexp))
                     {
                     $isregexp = 1;
                     }
                  else
                     {
                     $isregexp = 0;
                     }
               
                  if (defined($blacklist))
                     {
                     if (isblacklisted(\$blacklist, $isregexp, $host->name))
                        {
                        next;
                        }
                     }
                  if (defined($whitelist))
                     {
                     if (isnotwhitelisted(\$whitelist, $isregexp, $host->name))
                        {
                        next;
                        }
                      }

                  $host_state = $host->get_property('runtime.powerState')->val;
                  
             
                  if ($host_state eq "poweredOn")
                     {
                     $hpoweredon++;
                     if (!$alertonly)
                        {
                        $hpoweredon_out = $hpoweredon_out . $host->name . "($host_state)" . $multiline;
                        }
                     }
                  if (($host_state eq "poweredOff") || ($host_state eq "standBy") || ($host_state eq "unknown"))
                     {
                     $hpoweredoff++;
                     $hpoweredoff_out = $hpoweredoff_out . $host->name . "($host_state)" . $multiline;
                     $actual_state = 1;
                     $state = check_state($state, $actual_state);
                     }
                  }
   
          if ($subselect eq "all")
             {
             $output = $output . " - " . $hpoweredon . "/" . @$host_views . " Hosts powered on - ";
             $output = $output . $hpoweredoff . "/" . @$host_views . " Hosts powered off/standby/unknown";
             }
          else
             {
             $output = $hpoweredon . "/" . @$host_views . " Hosts powered on - ";
             $output = $output . $hpoweredoff . "/" . @$host_views . " Hosts powered off/standby/unknown" . $multiline;
             $output = $output . $hpoweredoff_out . $hpoweredon_out;
             }
          }
       }
  
    if (($subselect =~ m/listcluster.*$/) || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource', properties => ['name', 'overallStatus']);

       if (!defined($cluster_views))
          {
          print "Runtime error\n";
          exit 2;
          }

       if (!@$cluster_views)
          {
          if ($subselect eq "all")
             {
             $output = $output . " - No VMware Clusters";
             }
          else
             {
             $output = "No VMware Clusters.";
             }
          }
       else
          {
          foreach $cluster (@$cluster_views)
                  {
                  $cluster->update_view_data(['name', 'overallStatus']);

                  if (defined($isregexp))
                     {
                     $isregexp = 1;
                     }
                  else
                     {
                     $isregexp = 0;
                     }
               
                  if (defined($blacklist))
                     {
                     if (isblacklisted(\$blacklist, $isregexp, $cluster->name))
                        {
                        next;
                        }
                     }
                  if (defined($whitelist))
                     {
                     if (isnotwhitelisted(\$whitelist, $isregexp, $cluster->name))
                        {
                        next;
                        }
                      }

                  $cluster_state = $cluster->get_property('overallStatus')->val;

                  if ($cluster_state eq "green")
                     {
                     $cluster_green_cnt++;
                     if (!$alertonly)
                        {
                        $cluster_green_out = $cluster_green_out . $cluster->name . " (" . $cluster_state . ")" . $multiline;
                        $actual_state = check_health_state($cluster_state);
                        $state = check_state($state, $actual_state);
                        }
                     }
                  if ($cluster_state eq "gray")
                     {
                     $cluster_gray_cnt++;
                     $cluster_gray_out = $cluster_gray_out . $cluster->name . " (" . $cluster_state . ")" . $multiline;
                     $actual_state = check_health_state($cluster_state);
                     $state = check_state($state, $actual_state);
                     }
                  if ($cluster_state eq "red")
                     {
                     $cluster_red_cnt++;
                     $cluster_red_out = $cluster_red_out . $cluster->name . " (" . $cluster_state . ")" . $multiline;
                     $actual_state = check_health_state($cluster_state);
                     $state = check_state($state, $actual_state);
                     }
                  if ($cluster_state eq "yellow")
                     {
                     $cluster_yellow_cnt++;
                     $cluster_yellow_out = $cluster_yellow_out . $cluster->name . " (" . $cluster_state . ")" . $multiline;
                     $actual_state = check_health_state($cluster_state);
                     $state = check_state($state, $actual_state);
                     }
                  }

          if ($subselect eq "all")
             {
             $output = $output . " - " . $cluster_green_cnt . "/" . @$cluster_views . " Clusters green - ";
             $output = $output . $cluster_red_cnt . "/" . @$cluster_views . " Clusters red - ";
             $output = $output . $cluster_yellow_cnt . "/" . @$cluster_views . " Clusters yellow - ";
             $output = $output . $cluster_gray_cnt . "/" . @$cluster_views . " Clusters gray";
             }
          else
             {
             $output = $cluster_green_cnt . "/" . @$cluster_views . " Clusters green - ";
             $output = $output . $cluster_red_cnt . "/" . @$cluster_views . " Clusters red - ";
             $output = $output . $cluster_yellow_cnt . "/" . @$cluster_views . " Clusters yellow - ";
             $output = $output . $cluster_gray_cnt . "/" . @$cluster_views . " Clusters gray" . $multiline;
             $output = $output . $cluster_red_out . $cluster_yellow_out . $cluster_gray_out . $cluster_green_out;
             }
          }
       }
    
    if (($subselect eq "tools") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name', 'runtime.powerState', 'summary.guest']);

       if (!defined($vm_views))
          {
          print "Runtime error\n";
          exit 2;
          }

       if (!@$vm_views)
          {
          print "There are no VMs.\n";
          exit 2;
          }

       
       foreach $vm (@$vm_views)
               {
               $vm_cnt++;

               if (defined($isregexp))
                  {
                  $isregexp = 1;
                  }
               else
                  {
                  $isregexp = 0;
                  }
            
               if (defined($blacklist))
                  {
                  if (isblacklisted(\$blacklist, $isregexp, $vm->name))
                     {
                     $vm_ignored_cnt++;
                     next;
                     }
                  }
               if (defined($whitelist))
                  {
                  if (isnotwhitelisted(\$whitelist, $isregexp, $vm->name))
                     {
                     $vm_ignored_cnt++;
                     next;
                     }
                  }

# VirtualMachineToolsRunningStatus
# guestToolsExecutingScripts  VMware Tools is starting.
# guestToolsNotRunning        VMware Tools is not running.
# guestToolsRunning           VMware Tools is running. 
       
# VirtualMachineToolsVersionStatus
# guestToolsBlacklisted       VMware Tools is installed, but the installed version is known to have a grave bug and should be immediately upgraded.
# Since vSphere API 5.0
# guestToolsCurrent           VMware Tools is installed, and the version is current.
# guestToolsNeedUpgrade       VMware Tools is installed, but the version is not current.
# guestToolsNotInstalled      VMware Tools has never been installed.
# guestToolsSupportedNew      VMware Tools is installed, supported, and newer than the version available on the host.
# Since vSphere API 5.0
# guestToolsSupportedOld      VMware Tools is installed, supported, but a newer version is available.
# Since vSphere API 5.0
# guestToolsTooNew            VMware Tools is installed, and the version is known to be too new to work correctly with this virtual machine.
# Since vSphere API 5.0
# guestToolsTooOld            VMware Tools is installed, but the version is too old.
# Since vSphere API 5.0
# guestToolsUnmanaged         VMware Tools is installed, but it is not managed by VMWare. 

               if ($vm->get_property('runtime.powerState')->val eq "poweredOn")
                  {
                  $vm_guest = $vm->get_property('summary.guest');

                  if (exists($vm_guest->{toolsVersionStatus}) && defined($vm_guest->toolsVersionStatus) && exists($vm_guest->{toolsRunningStatus}) && defined($vm_guest->toolsRunningStatus))
                     {
                     if ($vm_guest->toolsVersionStatus ne "guestToolsNotInstalled")
                        {
                        if ($vm_guest->toolsRunningStatus ne "guestToolsNotRunning")
                           {
                           if ($vm_guest->toolsRunningStatus ne "guestToolsExecutingScripts")
                              {
                              if ($vm_guest->toolsVersionStatus eq "guestToolsBlacklisted")
                                 {
                                 $guestToolsBlacklisted_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,but the installed ";
                                 $tools_out = $tools_out ."version is known to have a grave bug and should ";
                                 $tools_out = $tools_out ."be immediately upgraded." . $multiline;
                                 $actual_state = 2;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsCurrent")
                                 {
                                 $guestToolsCurrent_cnt++;
                                 if (!$alertonly)
                                    {
                                    if (defined($showall))
                                       {
                                       $tools_out = $tools_out . "VM " . $vm->name . " Installed,running and current." . $multiline;
                                       }
                                    $actual_state = 0;
                                    $state = check_state($state, $actual_state);
                                    }
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsNeedUpgrade")
                                 {
                                 $guestToolsNeedUpgrade_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,version is not current." . $multiline;
                                 $actual_state = 1;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsSupportedNew")
                                 {
                                 $guestToolsSupportedNew_cnt++;
                                 if (defined($showall))
                                    {
                                    $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,supported and newer than the ";
                                    $tools_out = $tools_out ."version available on the host." . $multiline;
                                    }
                                 $actual_state = 0;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsSupportedOld")
                                 {
                                 $guestToolsSupportedOld_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,supported, but a newer version is available." . $multiline;
                                 $actual_state = 1;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsTooNew")
                                 {
                                 $guestToolsTooNew_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,but the version is known to be too new ";
                                 $tools_out = $tools_out ."to work correctly with this virtual machine." . $multiline;
                                 $actual_state = 2;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsTooOld")
                                 {
                                 $guestToolsTooOld_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,but the version is too old." . $multiline;
                                 $actual_state = 1;
                                 $state = check_state($state, $actual_state);
                                 }
                              if ($vm_guest->toolsVersionStatus eq "guestToolsUnmanaged")
                                 {
                                 $guestToolsUnmanaged_cnt++;
                                 $tools_out = $tools_out . "VM " . $vm->name . " Installed,running,but not managed by VMWare. " . $multiline;
                                 if (defined($openvmtools))
                                    {
                                    $actual_state = 0;
                                    }
                                 else
                                    {
                                    $actual_state = 1;
                                    }
                                 $state = check_state($state, $actual_state);
                                 }
                              }
                           else
                              {
                              $guestToolsUnknown_cnt++;
                              if (defined($showall))
                                 {
                                 $tools_out = $tools_out . "VM " . $vm->name . " Tools starting." . $multiline;
                                 }
                              $actual_state = 0;
                              $state = check_state($state, $actual_state);
                              }
                           }
                        else
                           {
                           $guestToolsNotRunning_cnt++;
                           $tools_out = $tools_out . "VM " . $vm->name . " Tools not running." . $multiline;
                           $actual_state = 1;
                           $state = check_state($state, $actual_state);
                           }
                        }
                     else
                        {
                        $guestToolsNotInstalled_cnt++;
                        $tools_out = $tools_out ."VM " . $vm->name . " Tools not installed." . $multiline;
                        $actual_state = 1;
                        $state = check_state($state, $actual_state);
                        }
                     }
                  else
                     {
                     $guestToolsUnknown_cnt++;
                     $tools_out = $tools_out . "VM " . $vm->name . " No information about VMware tools available. Please check!" . $multiline;
                     $actual_state = 1;
                     $state = check_state($state, $actual_state);
                     }
                  }
               else
                  {
                  if (!defined($vm_tools_poweredon_only))
                     {
                     if ($vm->get_property('runtime.powerState')->val eq "poweredOff")
                        {
                        $guestToolsPOF_cnt++;
                        if (defined($showall))
                           {
                           $tools_out = $tools_out . $vm->name . " powered off. Tools not running." . $multiline;
                           }
                        $actual_state = 0;
                        $state = check_state($state, $actual_state);
                        }
                     if ($vm->get_property('runtime.powerState')->val eq "suspended")
                        {
                        $guestToolsSuspendePOF_cnt++;
                        $tools_out = $tools_out . $vm->name . " suspended. Tools not running." . $multiline;
                        $actual_state = 0;
                        $state = check_state($state, $actual_state);
                        }
                     }
                  }
               }

       if ($subselect eq "all")
          {
          $output = $output . " - " . $vm_cnt . " VMs checked for VMWare Tools state, " . $vm_bad_cnt . " are not OK." . $multiline;
          }
       else
          {
          $output = $output . $vm_cnt . " VMs checked for VMWare Tools state, " . $vm_bad_cnt . " are not OK." . $multiline;
          if ($guestToolsCurrent_cnt > 0)
             {
             $output = $output . $guestToolsCurrent_cnt . " Installed,running and current." . $multiline;
             }
          if ($guestToolsBlacklisted_cnt > 0)
             {
             $output = $output . $guestToolsBlacklisted_cnt . " Installed,running,but the installed version is known to have a grave";
             $output = $output . " bug and should be immediately upgraded" . $multiline;;
             }
          if ($guestToolsNeedUpgrade_cnt > 0)
             {
             $output = $output . $guestToolsNeedUpgrade_cnt . " Installed,running,version is not current" . $multiline;
             }
          if ($guestToolsSupportedNew_cnt > 0)
             {
             $output = $output . $guestToolsSupportedNew_cnt . " Installed,running,supported and newer than the version available on the host" . $multiline;
             }
          if ($guestToolsSupportedOld_cnt > 0)
             {
             $output = $output . $guestToolsSupportedOld_cnt . " Installed,running,supported, but a newer version is available" . $multiline;
             }
          if ($guestToolsTooNew_cnt > 0)
             {
             $output = $output . $guestToolsTooNew_cnt . " Installed,running,but the version is known to be too new ";
             $output = $output . " too new to work correctly with this virtual machine" . $multiline;
             }
          if ($guestToolsTooOld_cnt > 0)
             {
             $output = $output . $guestToolsTooOld_cnt . " Installed,running,but the version is too old" . $multiline;
             }
          if ($guestToolsUnmanaged_cnt > 0)
             {
             $output = $output . $guestToolsUnmanaged_cnt . " Installed,running,but not managed by VMWare" . $multiline;
             }
          if ($guestToolsUnknown_cnt > 0)
             {
             $output = $output . $guestToolsUnknown_cnt . " Tools starting" . $multiline;
             }
          if ($guestToolsNotRunning_cnt > 0)
             {
             $output = $output . $guestToolsNotRunning_cnt . " Tools not running" . $multiline;
             }
          if ($guestToolsNotInstalled_cnt > 0)
             {
             $output = $output . $guestToolsNotInstalled_cnt . " Tools not installed" . $multiline;
             }
          if ($guestToolsUnknown_cnt > 0)
             {
             $output = $output . $guestToolsUnknown_cnt . " No information about VMware tools available." . $multiline;
             }
          if ($guestToolsPOF_cnt > 0)
             {
             $output = $output . $guestToolsPOF_cnt . " Powered off. Tools not running" . $multiline;
             }
          if ($guestToolsSuspendePOF_cnt > 0)
             {
             $output = $output . $guestToolsSuspendePOF_cnt . " Suspended. Tools not running" . $multiline;
             }
          $output = $output . $tools_out;
          }
       }
    

    if (($subselect eq "status") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $dc_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name', 'overallStatus']);
       $actual_state = 0;

       if (!defined($dc_views))
          {
          print "There is no datacenter\n";
          exit 2;
          }

       foreach $dc (@$dc_views)
               {
               if (defined($dc->overallStatus))
                  {
                  $overallStatus = $dc->overallStatus->val;

                  if ($overallStatus eq "green")
                     {
                     $vc_green_cnt++;
                     $tmp_output = $tmp_output . $dc->name . " overall status=" . $overallStatus . $multiline;
                     $actual_state = check_health_state($overallStatus);
                     $state = check_state($state, $actual_state);
                     }
                  if ($overallStatus eq "gray")
                     {
                     $vc_gray_cnt++;
                     $tmp_output = $tmp_output . $dc->name . " overall status=" . $overallStatus . $multiline;
                     $actual_state = check_health_state($overallStatus);
                     $state = check_state($state, $actual_state);
                     }
                  if ($overallStatus eq "red")
                     {
                     $vc_red_cnt++;
                     $tmp_output = $tmp_output . $dc->name . " overall status=" . $overallStatus . $multiline;
                     $actual_state = check_health_state($overallStatus);
                     $state = check_state($state, $actual_state);
                     }
                  if ($overallStatus eq "yellow")
                     {
                     $vc_yellow_cnt++;
                     $tmp_output = $tmp_output . $dc->name . " overall status=" . $overallStatus . $multiline;
                     $actual_state = check_health_state($overallStatus);
                     $state = check_state($state, $actual_state);
                     }
                  }
               else
                  {
                  $actual_state = 1;
                  $state = check_state($state, $actual_state);
                  $tmp_output = $tmp_output . "Maybe insufficient rights to access " . $dc->name . " status info on the DC" . $multiline;
                  }
               }

       if ($subselect eq "all")
          {
          $output = $output . " - " . $vc_green_cnt . "/" . @$dc_views . " Vcenters green - ";
          $output = $output . $vc_red_cnt . "/" . @$dc_views . " Vcenters red - ";
          $output = $output . $vc_yellow_cnt . "/" . @$dc_views . " Vcenters yellow - ";
          $output = $output . $vc_gray_cnt . "/" . @$dc_views . " Vcenters gray";
          }
       else
          {
          $output = $vc_green_cnt . "/" . @$dc_views . " Vcenters green - ";
          $output = $output . $vc_red_cnt . "/" . @$dc_views . " Vcenters red - ";
          $output = $output . $vc_yellow_cnt . "/" . @$dc_views . " Vcenters yellow - ";
          $output = $output . $vc_gray_cnt . "/" . @$dc_views . " Vcenters gray" . $multiline . $tmp_output;
          }
       }
    
    
    if (($subselect eq "issues") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $dc_views = Vim::find_entity_views(view_type => 'Datacenter', properties => ['name', 'configIssue']);
       $actual_state = 0;

       if (!defined($dc_views))
          {
          print "There is no datacenter\n";
          exit 2;
          }

       foreach $dc (@$dc_views)
               {
               $issues = $dc->configIssue;
               if (defined($issues))
                  {
                  $actual_state = 1;
                  foreach (@$issues)
                          {
                          $vc_name = ref($_);
                          $issue_cnt++;
                          if (defined($isregexp))
                             {
                             $isregexp = 1;
                             }
                          else
                             {
                             $isregexp = 0;
                             }
                       
                          if (defined($blacklist))
                             {
                             $issues_ignored_cnt++;
                             if (isblacklisted(\$blacklist, $isregexp, $vc_name))
                                {
                                next;
                                }
                             }
                          if (defined($whitelist))
                             {
                             if (isnotwhitelisted(\$whitelist, $isregexp, $vc_name))
                                {
                                next;
                                }
                              }
                          $issue_out = $issue_out . format_issue($_) . " (" . $dc->name . ")" . $multiline;
                          }
                  }
               }

       if ($subselect eq "all")
          {
          $output = $output . " - " . $issue_cnt . " config issues  - " . $issues_ignored_cnt  . " config issues ignored";
          }
       else
          {
          $output = $issue_cnt . " config issues - " . $issues_ignored_cnt  . " config issues ignored" . $multiline . $issue_out;
          }
       $state = check_state($state, $actual_state);
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown DC RUNTIME subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub version_lic
    {
    print "\n";
    print "$ProgName,Version $prog_version\n";
    print "\n";
    print "This vmware Infrastructure monitoring plugin is free software, and comes with ABSOLUTELY NO WARRANTY.\n";
    print "It may be used, redistributed and/or modified under the terms of the GNU General Public Licence \n";
    print "(see http://www.fsf.org/licensing/licenses/gpl.txt).\n\n";
    print "Copyright (c) 2013 all modifications starting from check_vmware_api.pl Martin Fuerstenau - Oce Printing Systems <martin.fuerstenau\@oce.com>\n";
    print "Copyright (c) 2008 op5 AB Kostyantyn Hushchyn <dev\@op5.com>\n";
    print "\n";
    }

sub help_options
    {
    print "   -h|--help=<all>                    The complete help for all.\n";
    print "   -h|--help=<dc|datacenter|vcenter>  Help for datacenter/vcenter checks.\n";
    print "   -h|--help=<host>                   Help for vmware host checks.\n";
    print "   -h|--help=<vm>                     Help for virtual machines checks.\n";
    print "   -h|--help=<cluster>                Help for cluster checks.\n";
    }

sub hint
    {
    print "\n";
    print "Some general information:\n";
    print "There are options like -B, --exclude=<black_list>, -W, --include=<white_list>,--isregexp or --multiline. These options are implemented for ";
    print "some selects/subselects but not for all. To make it more handy for the user and to avoid paging up and down we have listed these options more ";
    print "than once. So for every select statement all the options are listed that can be used there\n";
    print "\n";
    print "Example:\n";
    print "\n";
    print "    Host service info:\n";
    print "    ------------------\n";
    print "    -S, --select=service                shows host service info.\n";
    print "    -B, --exclude=<black_list>          blacklist services.\n";
    print "    -W, --include=<white_list>          whitelist services.\n";
    print "        --isregexp                      whether to treat blacklist and whitelist as regexp\n";
    print "        --multiline                     Multiline output in overview. This mean technically that\n";
    print "                                        a multiline output uses a HTML <br> for the GUI instead of\n";
    print "                                        Be aware that your messing connections (email, SMS...) must use\n";
    print "                                        a filter to file out the <br>. A sed oneliner like the following\n";
    print "                                        will do the job: sed 's/<[^<>]*>//g'\n";
    print "\n";
    }

sub print_help
    {
    my ($section) = @_;
    my $page;
    
    if (!defined($section))
       {
       $section = "all";
       }
    
    if ($section =~ m/^[a-z].*$/i)
       {
       $section = lc($section);
       if (!(($section eq "dc") || ($section eq "datacenter") || ($section eq "vcenter") || ($section eq "host") || ($section eq "vm") || ($section eq "all") || ($section eq "cluster")))
          {
          print "\n$section is not a valid value for help. Valid values are:\n\n";
          help_options();
          version_lic();
          exit 1;
          }
       }
    else
       {
       print "\nBecause the output of the complete help is very large you have to select what you want:\n\n";
       help_options();
       if(-t STDOUT) {
           print "<--Hit enter for next page-->";
           $page = <STDIN>;
           undef $page;
       }
       hint();
       if(-t STDOUT) {
            print "<--Hit enter for next page-->";
            $page = <STDIN>;
            undef $page;
       }
       version_lic();
       exit 0;
       }

    if (($section eq "dc") || ($section eq "datacenter") || ($section eq "vcenter") || ($section eq "host") || ($section eq "vm") || ($section eq "all") || ($section eq "cluster"))
       {
       version_lic();
       print "General options:\n";
       print "================\n";
       print "\n";
       print "-?, --usage                          Print usage information\n";
       print "-h, --help                           Print detailed help screen\n";
       print "-V, --version                        Print version information\n";
       print "    --ignore_unknown                 Sometimes 3 (unknown) is returned from a component.\n";
       print "                                     But the check itself is ok.\n";
       print "                                     With this option the plugin will return OK (0) instead of UNKNOWN (3).\n";
       print "    --ignore_warning                 Sometimes 2 (warning) is returned from a component.\n";
       print "                                     But the check itself is ok (from an operator view).\n";
       print "                                     With this option the plugin will return OK (0) instead of WARNING (1).\n";
       print "    --statelabels=<y/n>              Whether or not statelabels as described in the Nagios Plugin Developer\n";
       print "                                     Guidelines (OK, CRITICAL, WARNING etc.) will printed out. Technically\n";
       print "                                     these are not neccessary because the infomation is available via the colour\n";
       print "                                     in the WebGui (red/green/yellow etc.)and for notifications via the macros\n";
       print "                                     \$SERVICESTATE\$ and \$SERVICESTATEID\$. The default behaviour can be changed\n";
       print "                                     by setting the variable \$statelabels_def in the plugin from y to n.\n";
       print "-t, --timeout=INTEGER                Seconds before plugin times out (default: 90)\n";
       print "    --trace=<level>                  Set verbosity level of vSphere API request/respond trace.\n";
       print "\n";

       print "Options for authentication:\n";
       print "===========================\n";
       print "\n";
       print "                                     To reduce amounts of login/logout events in the vShpere logfiles or a lot of\n";
       print "                                     open sessions using sessionfiles the login part has been rewritten. Using session\n";
       print "                                     files is now the default. Only one session file per host or vCenter is used as\n";
       print "                                     default.\n";
       print "\n";
       print "                                     The sessionfile name is automatically set to the vSphere host or the vCenter\n";
       print "                                     (IP or name - whatever is used in the check).\n";
       print "\n";
       print "                                     Multiple sessions are possible using different session file names. To form different\n";
       print "                                     session file names the default name is enhenced by the value you set with\n";
       print "                                     --sessionfile.\n";
       print "\n";
       print "                                     NOTICE! All checks using the same session are serialized. So a lot of checks\n";
       print "                                     using only one session can cause timeouts. In this case you should enhence the\n";
       print "                                     number of sessions by using --sessionfile in the command definition and define\n";
       print "                                     the value in the service definition command as an extra argument so it can be used\n";
       print "                                     in the command definition as \$ARGn\$.\n";
       print "     --sessionfile=<sessionfile>     (Optional).Session file name enhancement.\n";
       print "     --sessionfiledir=<directory>    (Optional).If this option is set a path different from the path stored in\n";
       print "                                     \$sessionfile_dir_def, which is defined in the plugin will be used.\n";
       print "     --nosession                     (Optional). Don't use a session file. This is the old behaviour. It should\n";
       print "                                     not be used for production use because it can cause a lot of entries in the log\n";
       print "                                     files an therefore can cause abnormal growing of the log.\n";
       print "                                     IT SHOULD BE USED FOR TESTING PURPOSES ONLY!\n";
       print "-u, --username=<username>            Username to connect with.\n";
       print "-p, --password=<password>            Password to use with the username.\n";
       print "-f, --authfile=<path>                Authentication file with login and password.\n";
       print "                                     File syntax :\n";
       print "                                     username=<login>\n";
       print "                                     password=<password>\n";
       print "\n";
       }

#--- Data Center ----------------------

    if (($section eq "dc") || ($section eq "datacenter") || ($section eq "vcenter") || ($section eq "all"))
       {
       print "Monitoring the vmware datacenter:\n";
       print "=================================\n";
       print "\n";
       print "-D, --datacenter=<DCname>           Datacenter/Vcenter hostname.\n";
       print "    --sslport=<port>                If a SSL port different from 443 is used.\n";
       print "\n";
       print "Volumes:\n";
       print "--------\n";
       print "\n";
       print "-S, --select=volumes                Shows all datastore volumes info\n";
       print "or with\n";
       print "-s, --subselect=<name>              free space info for volume with name <name>\n\n";
       print "    --gigabyte                      Output in GB instead of MB\n";
       print "    --usedspace                     Output used space instead of free\n";
       print "\n";
       print "    --perf_free_space               Perfdata for free space instead of used space. In versions prior to 0.9.18\n";
       print "                                    performance data was always as freespace even if you selected --usedspace.\n";
       print "                                    Now with --usedspace perf data will be also in used space.\n";
       print "                                    This option is mainly to preserve existing performce data.\n";
       print "\n";
       print "    --alertonly                     List only alerting volumes\n";
       print "-B, --exclude=<black_list>          Blacklist volumes.\n";
       print "-W, --include=<white_list>          Whitelist volumes.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat name, blacklist and whitelist as regexp\n";
       print "-w, --warning=<threshold>           Warning threshold.\n";
       print "-c, --critical=<threshold>          Critical threshold.\n";
       print "                                    Thresholds should be either a simple counter or a percentage\n";
       print "                                    value in the n% (i.e. 90%). If checking more than a single\n";
       print "                                    with --usedspace volume only percent is allowed as threshold or\n";
       print "                                    --spaceleft must be used.\n";
       print "    --spaceleft                     This has to be used in conjunction with thresholds as mentioned above.\n";
       print "                                    The thresholds must be specified as the space left on device and with the\n";
       print "                                    same unit (MB or GB).\n";
       print "\n";
       print "Runtime Info:\n";
       print "-------------\n";
       print "\n";
       print "-S, --select=runtime                Shows all runtime info for the datacenter/Vcenter.\n";
       print "                                    No thresholds are allowed here\n";
       print "or with\n";
       print "-s, --subselect=listvms             List of vmware machines and their power state..\n";
       print "\n";
       print "                                    BEWARE!! In larger environments systems can cause trouble displaying\n";
       print "                                    the informations needed due to the mass of data.\n";
       print "                                  . Use --alertonly to avoid this.\n";
       print "\n";
       print "-B, --exclude=<black_list>          Blacklist VMs.\n";
       print "-W, --include=<white_list>          Whitelist VMs.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "    --alertonly                     List only alerting VMs. Important here to avoid masses of data.\n";
       print "or\n";
       print "-s, --subselect=listhost            List of VMware ESX hosts and their power state..\n";
       print "                                    Power state can be (from the docs):\n";
       print "                                    - poweredOff  The host was specifically powered off by the user\n";
       print "                                                  through VirtualCenter. This state is not a cetain state,\n";
       print "                                                  because after VirtualCenter issues the command to power\n";
       print "                                                  off the host, the host might crash, or kill all the\n";
       print "                                                  processes but fail to power off.\n";
       print "                                    - poweredOn   The host is powered on\n";
       print "                                    - standBy     The host was specifically put in standby mode, either\n";
       print "                                                  explicitly by the user, or automatically by DPM. This\n";
       print "                                                  state is not a cetain state, because after VirtualCenter\n";
       print "                                                  issues the command to put the host in stand-by state,\n";
       print "                                                  the host might crash, or kill all the processes but fail\n";
       print "                                                  to power off.\n";
       print "                                    - unknown     If the host is disconnected, or notResponding, we can not\n";
       print "                                                  possibly have knowledge of its power state. Hence, the\n";
       print "                                                  host is marked as unknown.\n";
       print "\n";
       print "                                    BEWARE!! In larger environments systems can cause trouble displaying\n";
       print "                                    the informations needed due to the mass of data.\n";
       print "                                  . Use --alertonly to avoid this.\n";
       print "\n";
       print "-B, --exclude=<black_list>          Blacklist VMware ESX hosts.\n";
       print "-W, --include=<white_list>          Whitelist VMware ESX hosts.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "    --alertonly                     List only alerting hosts. Important here to avoid masses of data.\n";
       print "or\n";
       print "-s, --subselect=listcluster         List of vmware clusters and their states.\n";
       print "                                    States can be (from the docs):\n";
       print "                                    - gray    The status is unknown.\n";
       print "                                    - green   The entity is OK.\n";
       print "                                    - red     The entity definitely has a problem.\n";
       print "                                    - yellow  The entity might have a problem.\n";
       print "-B, --exclude=<black_list>          Blacklist VMware cluster.\n";
       print "-W, --include=<white_list>          Whitelist VMware cluster.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "    --alertonly                     List only alerting hosts. Important here to avoid masses of data.\n";
       print "or\n";
       print "-s, --subselect=issues              All issues for the host.\n";
       print "-B, --exclude=<black_list>          Blacklist issues.\n";
       print "-W, --include=<white_list>          Whitelist issues.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or\n";
       print "-s, --subselect=status              Overall object status (gray/green/red/yellow).\n";
       print "                                    State can be (from the docs):\n";
       print "                                    - gray    The status is unknown.\n";
       print "                                    - green   The entity is OK.\n";
       print "                                    - red     The entity definitely has a problem.\n";
       print "                                    - yellow  The entity might have a problem.\n";
       print "or\n";
       print "-s, --subselect=tools               Vmware Tools status. Tool status can be:\n";
       print "                                    - Installed,running and current.\n";
       print "                                    - Installed,running,but the installed version is known to\n";
       print "                                      have a grave bug and should be immediately upgraded.\n";
       print "                                    - Installed,running,version is not current\n";
       print "                                    - Installed,running,supported and newer than the\n";
       print "                                      version available on the host\n";
       print "                                    - Installed,running,supported, but a newer version is available\n";
       print "                                    - Installed,running,but the version is known to be too new\n";
       print "                                      too new to work correctly with this virtual machine\n";
       print "                                    - Installed,running,but the version is too old\n";
       print "                                    - Installed,running,but not managed by VMWare\n";
       print "    --poweredonly                   List only VMs which are powered on.\n";
       print "    --showall                       List all VMs. Otherwise only VM with problems are listed.\n";
       print "-B, --exclude=<black_list>          Blacklist VMs.\n";
       print "-W, --include=<white_list>          Whitelist VMs.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "    --alertonly                     List only alerting VMs. Important here to avoid masses of data.\n";
       print "\n";
       print "SOAP API:\n";
       print "---------\n";
       print "\n";
       print "-S, --select=soap                   simple check to verify a successfull connection\n";
       print "                                    to VMWare SOAP API.\n";
       print "\n";
       }

#--- Host ----------------------

    if (($section eq "host") || ($section eq "all"))
       {
       print "Monitoring the vmware host:\n";
       print "===========================\n";
       print "\n";
       print "-H, --host=<hostname>               ESX or ESXi hostname.\n";
       print "    --sslport=<port>                If a SSL port different from 443 is used.\n";
       print "\n";
       print "Uptime:\n";
       print "-------\n";
       print "\n";
       print "-S, --select=uptime                 Displays uptime of the vmware host.\n";
       print "or with\n";
       print "\n";
       print "CPU:\n";
       print "----\n";
       print "\n";
       print "-S, --select=cpu                    CPU usage in percentage\n";
       print "-w, --warning=<threshold>           Warning threshold in percent.\n";
       print "-c, --critical=<threshold>          Critical threshold in percent.\n";
       print "or with\n";
       print "-s, --subselect=ready               Percentage of time that the virtual machine was\n";
       print "                                    ready, but could not get scheduled to run on the\n";
       print "                                    physical CPU. CPU ready time is dependent on the\n";
       print "                                    number of virtual machines on the host and their\n";
       print "                                    CPU loads. High or growing ready time can be a\n";
       print "                                    hint CPU bottlenecks\n";
       print "or\n";
       print "-s, --subselect=wait                CPU time spent in wait state. The wait total includes\n";
       print "                                    time spent the CPU idle, CPU swap wait, and CPU I/O\n";
       print "                                    wait states. High or growing wait time can be a\n";
       print "                                    hint I/O bottlenecks.\n";
       print "or\n";
       print "-s, --subselect=usage               Actively used CPU of the host, as a percentage of\n";
       print "                                    the total available CPU. Active CPU is approximately\n";
       print "                                    equal to the ratio of the used CPU to the available\n";
       print "                                    CPU.\n";
       print "\n";
       print "                                    Available CPU = # of physical CPUs x clock rate\n";
       print "\n";
       print "                                    100% represents all CPUs on the host. For example,\n";
       print "                                    if a four-CPU host is running a virtual machine with\n";
       print "                                    two CPUs, and the usage is 50%, the host is using two\n";
       print "                                    CPUs completely.\n";
       print "-w, --warning=<threshold>           Warning threshold in percent.\n";
       print "-c, --critical=<threshold>          Critical threshold in percent.\n";
       print "\n";
       print "Memory:\n";
       print "-------\n";
       print "\n";
       print "-S, --select=mem                    All mem info(except overall and no thresholds)\n";
       print "or with\n";
       print "-s, --subselect=usage               Average mem usage in percentage\n";
       print "or\n";
       print "-s, --subselect=consumed            Amount of machine memory used on the host. Consumed\n";
       print "                                    memory includes Includes memory used by the Service\n";
       print "                                    Console, the VMkernel vSphere services, plus the\n";
       print "                                    total consumed metrics for all running virtual\n";
       print "                                    machines in MB\n";
       print "or\n";
       print "-s, --subselect=swapused            Amount of memory that is used by swap. Sum of memory\n";
       print "                                    swapped of all powered on VMs and vSphere services\n";
       print "                                    on the host in MB. In case of an error all VMs with their\n";
       print "                                    swap used will be displayed. Use --multiline to have\n";
       print "                                    a better formatted output.\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or\n";
       print "-s, --subselect=overhead            Additional mem used by VM Server in MB\n";
       print "or\n";
       print "-s, --subselect=memctl              The sum of all vmmemctl values in MB for all powered-on\n";
       print "                                    virtual machines, plus vSphere services on the host.\n";
       print "                                    If the balloon target value is greater than the balloon\n";
       print "                                    value, the VMkernel inflates the balloon, causing more\n";
       print "                                    virtual machine memory to be reclaimed. If the balloon\n";
       print "                                    target value is less than the balloon value, the VMkernel\n";
       print "                                    deflates the balloon, which allows the virtual machine to\n";
       print "                                    consume additional memory if needed.used by VM memory\n";
       print "                                    control driver. In case of an error all VMs with their\n";
       print "                                    vmmemctl values will be displayed. Use --multiline to have\n";
       print "                                    a better formatted output.\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       print "Network:\n";
       print "-------\n";
       print "\n";
       print "-S, --select=net                    Shows net info\n";
       print "-B, --exclude=<black_list>          Blacklist NICs.\n";
       print "    --isregexp                      Whether to treat blacklist as regexp\n";
       print "or with\n";
       print "-s, --subselect=usage               Overall network usage in KBps(Kilobytes per Second).\n";
       print "or\n";
       print "-s, --subselect=receive             Receive in KBps(Kilobytes per Second).\n";
       print "or\n";
       print "-s, --subselect=send                Send in KBps(Kilobytes per Second).\n";
       print "or\n";
       print "-s, --subselect=nic                 Check all active NICs.\n";
       print "-B, --exclude=<black_list>          Blacklist NICs.\n";
       print "    --isregexp                      Whether to treat blacklist as regexp\n";
       print "\n";
       print "Volumes:\n";
       print "--------\n";
       print "\n";
       print "-S, --select=volumes                Shows all datastore volumes info\n";
       print "or with\n";
       print "-s, --subselect=<name>              Free space info for volume with name <name>\n\n";
       print "    --gigabyte                      Output in GB instead of MB\n";
       print "    --usedspace                     Output used space instead of free\n";
       print "\n";
       print "    --perf_free_space               Perfdata for free space instead of used space. In versions prior to 0.9.18\n";
       print "                                    performance data was always as freespace even if you selected --usedspace.\n";
       print "                                    Now with --usedspace perf data will be also in used space.\n";
       print "                                    This option is mainly to preserve existing performce data.\n";
       print "\n";
       print "    --alertonly                     List only alerting volumes\n";
       print "-B, --exclude=<black_list>          Blacklist volumes.\n";
       print "-W, --include=<white_list>          Whitelist volumes.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat name, blacklist and whitelist as regexp\n";
       print "-w, --warning=<threshold>           Warning threshold.\n";
       print "-c, --critical=<threshold>          Critical threshold.\n";
       print "                                    Thresholds should be either a simple counter or a percentage\n";
       print "                                    value in the n% (i.e. 90%). If checking more than a single\n";
       print "                                    with --usedspace volume only percent is allowed as threshold or\n";
       print "                                    --spaceleft must be used.\n";
       print "    --spaceleft                     This has to be used in conjunction with thresholds as mentioned above.\n";
       print "                                    The thresholds must be specified as the space left on device and with the\n";
       print "                                    same unit (MB or GB).\n";
       print "\n";
       print "Disk I/O:\n";
       print "---------\n";
       print "\n";
       print "-S, --select=io                     Shows all disk io info. Without subselect no thresholds\n";
       print "                                    can be given. All I/O values are aggregated from historical\n";
       print "                                    intervals over the past 24 hours with a 5 minute sample rate\n";
       print "or with\n";
       print "-s, --subselect=aborted             Number of aborted SCSI commands\n";
       print "or\n";
       print "-s, --subselect=resets              Number of SCSI bus resets\n";
       print "or\n";
       print "-s, --subselect=read                Average number of kilobytes read from the disk each second\n";
       print "                                    Rate at which data is read from each LUN on the host.\n";
       print "                                    read rate = # blocksRead per second x blockSize\n";
       print "                                    issued from the Guest OS to the virtual machine.\n";
       print "or\n";
       print "-s, --subselect=read_latency        Average amount of time (ms) to process a SCSI read command\n";
       print "                                    issued from the Guest OS to the virtual machine.\n";
       print "or\n";
       print "-s, --subselect=write               Average number of kilobytes written to disk each second.\n";
       print "                                    Rate at which data is written to each LUN on the host.\n";
       print "                                    write rate = # blocksRead per second x blockSize\n";
       print "or\n";
       print "-s, --subselect=write_latency       Average amount of time (ms) taken to process a SCSI write\n";
       print "                                    command issued by the Guest OS to the virtual machine.\n";
       print "or\n";
       print "-s, --subselect=usage               Aggregated disk I/O rate. For hosts, this metric includes\n";
       print "                                    the rates for all virtual machines running on the host\n";
       print "or\n";
       print "-s, --subselect=kernel_latency      Average amount of time (ms) spent by VMkernel processing\n";
       print "                                    each SCSI command.\n";
       print "or\n";
       print "-s, --subselect=device_latency      Average amount of time (ms) to complete a SCSI command\n";
       print "                                    from the physical device\n";
       print "or\n";
       print "-s, --subselect=queue_latency       Average amount of time (ms) spent in the VMkernel queue,\n";
       print "or\n";
       print "-s, --subselect=total_latency       Average amount of time (ms) taken during the collection interval\n";
       print "                                    to process a SCSI command issued by the guest OS to the virtual\n";
       print "                                    machine. The sum of kernelWriteLatency and deviceWriteLatency.\n";
       print "\n";
       print "Host mounted media:\n";
       print "-------------------\n";
       print "\n";
       print "-S, --select=hostmedia              List vm's with attached host mounted media like cd,dvd or\n";
       print "                                    floppy drives. This is important for monitoring because a\n";
       print "                                    virtual machine with a mount cd or dvd drive can not be\n";
       print "                                    moved to another host.\n";
       print "-B, --exclude=<black_list>          Blacklist VMs.\n";
       print "-W, --include=<white_list>          Whitelist VMs.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --listall                       List all VMs with all mounted media.\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       print "Service info:\n";
       print "-------------\n";
       print "-S, --select=service                Shows host service info.\n";
       print "-B, --exclude=<black_list>          Blacklist services.\n";
       print "-W, --include=<white_list>          Whitelist services.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       print "Runtime info:\n";
       print "-------------\n";
       print "-S, --select=runtime                Shows runtime info. Used without -s show all runtime info:\n";
       print "                                    VMs, overall status, connection state, health, storagehealth, temperature\n";
       print "                                    and sensor are represented as one value and without thresholds.\n";
       print "or with\n";
       print "-s, --subselect=con                 Shows connection state.\n";
       print "or\n";
       print "-s, --subselect=listvms             List of vmware machines and their statuses.\n";
       print "-B, --exclude=<black_list>          Blacklist VMs.\n";
       print "-W, --include=<white_list>          Whitelist VMs.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or\n";
       print "-s, --subselect=status              Overall object status (gray/green/red/yellow).\n";
       print "                                    State can be (from the docs):\n";
       print "                                    - gray    The status is unknown.\n";
       print "                                    - green   The entity is OK.\n";
       print "                                    - red     The entity definitely has a problem.\n";
       print "                                    - yellow  The entity might have a problem.\n";
       print "or\n";
       print "-s, --subselect=health              Checks cpu/storage/memory/sensor status.\n";
       print "    --listsensors                   List all available sensors(use for listing purpose only)\n";
       print "\n";
       print "    --nostoragestatus               This is to avoid a double alarm if you use -s health and\n";
       print "                                    -s storagehealth.\n";
       print "\n";
       print "-B, --exclude=<black_list>          Blacklist storage, memory and sensors.\n";
       print "-W, --include=<white_list>          Whitelist storage, memory and sensors.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "or\n";
       print "-s, --subselect=storagehealth       Local(!) storage status check.\n";
       print "-B, --exclude=<black_list>          Blacklist storage.\n";
       print "-W, --include=<white_list>          Whitelist storage.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or\n";
       print "-s, --subselect=temp                Lists all temperature sensors.\n";
       print "-B, --exclude=<black_list>          Blacklist sensors.\n";
       print "-W, --include=<white_list>          Whitelist sensors.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or\n";
       print "-s, --subselect=issues              Lists all configuration issues for the host.\n";
       print "-B, --exclude=<black_list>          Blacklist configuration issues.\n";
       print "-W, --include=<white_list>          Whitelist configuration issues.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       print "Storage info:\n";
       print "-------------\n";
       print "\n";
       print "-S, --select=storage                Shows Host storage info.\n";
       print "\n";
       print "                                    BEWARE!! Without a subselect only a summary will be listed.\n";
       print "                                    Larger environments in SAN systems can cause trouble displaying the\n";
       print "                                    informations needed due to the mass of data even when used with subselects\n";
       print "                                  . Use --alertonly to avoid this.\n";
       print "\n";
       print "-B, --exclude=<black_list>          Blacklist adapters, luns (use blacklist on canonical names for it)\n";
       print "                                    and paths. All items can be in one blacklist. Beware of regexp.\n";
       print "                                    A given regexp must give a destinct result.\n";
       print "-W, --include=<white_list>          Whitelist adapters, luns (use whitelist on canonical names for it)\n";
       print "                                    and paths. All items can be in one whitelist. Beware of regexp.\n";
       print "                                    A given regexp must give a destinct result.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "or with\n";
       print "-s, --subselect=adapter             List host bus adapters.\n";
       print "-B, --exclude=<black_list>          Blacklist adapters. Blacklisted adapters will not be displayed.\n";
       print "-W, --include=<white_list>          Whitelist adapters.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or with\n";
       print "-s, --subselect=lun                 List SCSI logical units. The listing will include:\n";
       print "                                    - LUN\n";
       print "                                    - canonical name of the disc\n";
       print "                                    - all of displayed name which is not part of the canonical name\n";
       print "                                    - the status\n";
       print "-B, --exclude=<black_list>          Blacklist luns (use blacklist on canonical names for it).\n";
       print "                                    Blacklisted luns will not be displayed.\n";
       print "-W, --include=<white_list>          Whitelist luns (use whitelist on canonical names for it).\n";
       print "                                    Only whitelisted adapters will be displayed.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --alertonly                     List only alerting units. Important here to avoid masses of data.\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "or with\n";
       print "-s, --subselect=path                List multipaths and the associated paths.\n";
       print "    --standbyok                     For storage systems where a standby multipath\n";
       print "                                    is ok and not a warning.\n";
       print "-B, --exclude=<black_list>          Blacklist paths.\n";
       print "-W, --include=<white_list>          Whitelist paths.\n";
       print "                                    A multipath SCSI ID is in the form:\n";
       print "                                    02003c000060a98000375274315a244276694e67684c554e202020\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat blacklist and whitelist as regexp\n";
       print "    --alertonly                     List only alerting units. Important here to avoid masses of data.\n";
       print "    --multiline                     Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       print "SOAP API:\n";
       print "---------\n";
       print "\n";
       print "-S, --select=soap                   Simple check to verify a successfull connection\n";
       print "                                    to VMWare SOAP API.\n";
       print "\n";
       }


#--- Virtual machine ----------------------

    if (($section eq "vm") || ($section eq "all"))
       {
       print "Monitoring a virtual machine via vmware datacenter or vmware host:\n";
       print "==================================================================\n";
       print "\n";
       print "-D, --datacenter=<DCname>           Datacenter hostname.\n";
       print "  or \n";
       print "-H, --host=<hostname>               ESX or ESXi hostname.\n";
       print "\n";
       print "-N, --name=<vmname>                 Virtual machine name.\n";
       print "    --sslport=<port>                If a SSL port different from 443 is used.\n";
       print "\n";
       print "CPU:\n";
       print "----\n";
       print "\n";
       print "-S, --select=cpu                    CPU usage in percentage\n";
       print "-w, --warning=<threshold>           Warning threshold in percent.\n";
       print "-c, --critical=<threshold>          Critical threshold in percent.\n";
       print "or with\n";
       print "-s, --subselect=ready               Percentage of time that the virtual machine was\n";
       print "                                    ready, but could not get scheduled to run on the\n";
       print "                                    physical CPU. CPU ready time is dependent on the\n";
       print "                                    number of virtual machines on the host and their\n";
       print "                                    CPU loads. High or growing ready time can be a\n";
       print "                                    hint CPU bottlenecks\n";
       print "or\n";
       print "-s, --subselect=wait                CPU time spent in wait state. The wait total includes\n";
       print "                                    time spent the CPU idle, CPU swap wait, and CPU I/O\n";
       print "                                    wait states. High or growing wait time can be a\n";
       print "                                    hint I/O bottlenecks.\n";
       print "or\n";
       print "-s, --subselect=usage               Amount of actively used virtual CPU, as a percentage\n";
       print "                                    of total available CPU. This is the host's view of\n";
       print "                                    the CPU usage, not the guest operating system view.\n";
       print "                                    It is the average CPU utilization over all available\n";
       print "                                    virtual CPUs in the virtual machine. For example, if\n";
       print "                                    a virtual machine with one virtual CPU is running on\n";
       print "                                    a host that has four physical CPUs and the CPU usage\n";
       print "                                    is 100%, the virtual machine is using one physical CPU\n";
       print "                                    completely. \n";
       print "-w, --warning=<threshold>           Warning threshold in percent.\n";
       print "-c, --critical=<threshold>          Critical threshold in percent.\n";
       print "\n";
       print "Memory:\n";
       print "-------\n";
       print "\n";
       print "-S, --select=mem                    all mem info(except overall and no thresholds)\n";
       print "or with\n";
       print "-s, --subselect=usage               Average mem usage in percentage of configured virtual\n";
       print "                                    machine \"physical\" memory.\n";
       print "or\n";
       print "-s, --subselect=consumed            Amount of guest physical memory in MB consumed by the\n";
       print "                                    virtual machine for guest memory. Consumed memory does\n";
       print "                                    not include overhead memory. It includes shared memory\n";
       print "                                    and memory that might be reserved, but not actually\n";
       print "                                    used. Use this metric for charge-back purposes.\n";
       print "                                    vm consumed memory = memory granted - memory saved\n";
       print "or\n";
       print "-s, --subselect=memctl              Amount of guest physical memory that is currently\n";
       print "                                    reclaimed from the virtual machine through ballooning.\n";
       print "                                    This is the amount of guest physical memory that has been\n";
       print "                                    allocated and pinned by the balloon driver.\n";
       print "\n";
       print "Network:\n";
       print "-------\n";
       print "\n";
       print "-S, --select=net                    Shows net info\n";
       print "or with\n";
       print "-s, --subselect=usage               Overall network usage in KBps(Kilobytes per Second).\n";
       print "or\n";
       print "-s, --subselect=receive             Receive in KBps(Kilobytes per Second).\n";
       print "or\n";
       print "-s, --subselect=send                Send in KBps(Kilobytes per Second).\n";
       print "\n";
       print "Disk I/O:\n";
       print "---------\n";
       print "\n";
       print "-S, --select=io                     Shows all disk io info. Without subselect no thresholds\n";
       print "                                    can be given. All I/O values are aggregated from historical\n";
       print "                                    intervals over the past 24 hours with a 5 minute sample rate.\n";
       print "or with\n";
       print "-s, --subselect=read                Average number of kilobytes read from the disk each second.\n";
       print "or\n";
       print "-s, --subselect=write               Average number of kilobytes written to disk each second.\n";
       print "or\n";
       print "-s, --subselect=usage               Aggregated disk I/O rate.\n";
       print "or\n";
       print "\n";
       print "Runtime Info:\n";
       print "-------------\n";
       print "\n";
       print "-S, --select=runtime                Shows runtime info, When used without subselect\n";
       print "                                    no thresholds can be given.\n";
       print "or with\n";
       print "-s, --subselect=con                 Shows the connection state. Connection state can be:\n";
       print "                                    connected	The server has access to the virtual machine.\n";
       print "                                    disconnected	When checked directly by a VMware host, then\n";
       print "                                                  the disconnected state is not possible. However,\n";
       print "                                                  when accessed through VirtualCenter, the state\n";
       print "                                                  of a virtual machine is set to disconnected if\n";
       print "                                                  the hosts that manage the virtual machine becomes\n";
       print "                                                  unavailable.\n";
       print "                                    inaccessible	One or more of the virtual machine configuration\n";
       print "                                                  files are inaccessible. For example, this can be\n";
       print "                                                  due to transient disk failures. In this case, no\n";
       print "                                                  configuration can be returned for a virtual machine.\n";
       print "                                    invalid	The virtual machine configuration format is invalid.\n";
       print "                                                  Thus, it is accessible on disk, but corrupted in a\n";
       print "                                                  way that does not allow the server to read the content\n";
       print "                                                . In this case, no configuration can be returned for\n";
       print "                                                  a virtual machine.\n";
       print "                                    orphaned	The virtual machine is no longer registered on the\n";
       print "                                                  host it is associated with. For example, a virtual\n";
       print "                                                  machine that is unregistered or deleted directly on\n";
       print "                                                  a host managed by VirtualCenter shows up in this state.\n";
       print "or with\n";
       print "-s, --subselect=powerstate          Virtual machine power state poweredOn, poweredOff, suspended)\n";
       print "or with\n";
       print "-s, --subselect=status              Overall object status (gray/green/red/yellow)\n";
       print "                                    State can be (from the docs):\n";
       print "                                    - gray    The status is unknown.\n";
       print "                                    - green   The entity is OK.\n";
       print "                                    - red     The entity definitely has a problem.\n";
       print "                                    - yellow  The entity might have a problem.\n";
       print "or with\n";
       print "-s, --subselect=consoleconnections  Console connections to VM.\n";
       print "-w, --warning=<threshold>           Warning threshold.\n";
       print "-c, --critical=<threshold>          Critical threshold.\n";
       print "or with\n";
       print " -s, --subselect=gueststate         Guest OS status. Needs VMware Tools installed and running.\n";
       print "                                    The status can be:\n";
       print "                                    running      -> Guest is running normally. (Ok)\n";
       print "                                    shuttingdown -> Guest has a pending shutdown command. (Warning)\n";
       print "                                    resetting    -> Guest has a pending reset command. (Warning)\n";
       print "                                    standby      -> Guest has a pending standby command. (Warning)\n";
       print "                                    notrunning   -> Guest is not running. (Warning)\n";
       print "                                    unknown      -> Guest information is not available. (Unknown)\n";
       print "\n";
       print "                                    Due to the fact that it depends on running VMware tools some of\n";
       print "                                    the tools stats are checked here either:\n";
       print "                                    - VMware tools are starting. (Warning)\n";
       print "                                    - VMware tools are not running.\n";
       print "                                      (Warning) if VM up and running.\n";
       print "                                      (Ok) if VM powerd off or suspended.\n";
       print "or with\n";
       print " -s, --subselect=tools              Vmware tools  status. The status can be:\n";
       print "                                    - VMware tools are starting. (Warning)\n";
       print "                                    - VMware tools are not running.\n";
       print "                                      (Warning) if VM up and running.\n";
       print "                                      (Ok) if VM powerd off or suspended.\n";
       print "                                    - VMware tools are running. (Ok) \n";
       print "                                    - VMware tools are installed, but the installed version is known\n";
       print "                                      to have a grave bug and should be immediately upgraded. (Critical)\n";
       print "                                    - VMware tools are installed, but the version is not current. (Warning)\n";
       print "                                    - VMware tools were never been installed. (Warning)\n";
       print "                                    - VMware tools are installed, supported, and newer than the version\n";
       print "                                      available on the host. (Warning)\n";
       print "                                    - No information about VMware tools available. (Warning)\n";
       print "\n";
       print "                                    New since vSphere API 5.0:\n";
       print "                                    - VMware tools are installed, and the version is current. (Ok)\n";
       print "                                    - VMware tools are installed, supported, but a newer version is\n";
       print "                                      available. (Warning)\n";
       print "                                    - VMware tools are installed, and the version is known to be too new to\n";
       print "                                      work correctly with this virtual machine. (Critical)\n";
       print "                                    - VMware tools are installed, but the version is too old. (Warning)\n";
       print "                                    - VMware tools are installed, but it is not managed by VMWare. (Critical)\n";
       print "or with\n";
       print " -s, --subselect=issues             All issues for the host\n";
       print "     --multiline                    Multiline output in overview. This mean technically that\n";
       print "                                    a multiline output uses a HTML <br> for the GUI instead of\n";
       print "                                    Be aware that your messing connections (email, SMS...) must use\n";
       print "                                    a filter to file out the <br>. A sed oneliner like the following\n";
       print "                                    will do the job: sed 's/<[^<>]*>//g'\n";
       print "\n";
       }

#--- Cluster ----------------------

    if (($section eq "all") || ($section eq "cluster"))
       {
       print "Monitoring a vmware cluster via vmware datacenter or vmware host:\n";
       print "=================================================================\n";
       print "\n";
       print "-D, --datacenter=<DCname>           Datacenter hostname.\n";
       print "  or \n";
       print "-H, --host=<hostname>               ESX or ESXi hostname.\n";
       print "\n";
       print "-C, --cluster=<clustername>         ESX or ESXi clustername.\n";
       print "    --sslport=<port>                If a SSL port different from 443 is used.\n";
   
       print "-S, --select=COMMAND\n";
       print "   Specify command type (cpu,mem,net,io,volumes,runtime, ...)\n";
       print "-s, --subselect=SUBCOMMAND\n";
       print "   Specify subselect\n";
       print "\n";
       print "-B, --exclude=<black_list>\n";
       print "   Specify black list\n";
       print "\n";
       print "    Cluster specific :\n";
       print "\n";
       print "Memory:\n";
       print "-------\n";
       print "\n";
       print "        * cluster - shows cluster services info\n";
       print "            + effectivecpu - total available cpu resources of all hosts within cluster\n";
       print "            + effectivemem - total amount of machine memory of all hosts in the cluster\n";
       print "            + failover - vmware HA number of failures that can be tolerated\n";
       print "            + cpufainess - fairness of distributed cpu resource allocation\n";
       print "            + memfainess - fairness of distributed mem resource allocation\n";
       print "            ^ only effectivecpu and effectivemem values for cluster services\n";
       print "        * runtime - shows runtime info\n";
       print "            + listvms - list of vmware machines in cluster and their statuses\n";
       print "            + listhost - list of vmware esx host servers in cluster and their statuses\n";
       print "            + status - overall cluster status (gray/green/red/yellow)\n";
       print "                                    States can be (from the docs):\n";
       print "                                    - gray    The status is unknown.\n";
       print "                                    - green   The entity is OK.\n";
       print "                                    - red     The entity definitely has a problem.\n";
       print "                                    - yellow  The entity might have a problem.\n";
       print "            + issues - all issues for the cluster\n";
       print "                b - blacklist issues\n";
       print "            ^ all cluster runtime info\n";
       print "\n";
       print "Volumes:\n";
       print "--------\n";
       print "\n";
       print "-S, --select=volumes                Shows all datastore volumes info\n";
       print "or with\n";
       print "-s, --subselect=<name>              free space info for volume with name <name>\n\n";
       print "    --gigabyte                      Output in GB instead of MB\n";
       print "    --usedspace                     Output used space instead of free\n";
       print "\n";
       print "    --perf_free_space               Perfdata for free space instead of used space. In versions prior to 0.9.18\n";
       print "                                    performance data was always as freespace even if you selected --usedspace.\n";
       print "                                    Now with --usedspace perf data will be also in used space.\n";
       print "                                    This option is mainly to preserve existing performce data.\n";
       print "\n";
       print "    --alertonly                     List only alerting volumes\n";
       print "-B, --exclude=<black_list>          Blacklist volumes.\n";
       print "-W, --include=<white_list>          Whitelist volumes.\n";
       print "\n";
       print "                                    Use blacklist OR(!) whitelist. Using both in one statement\n";
       print "                                    is not allowed.\n";
       print "\n";
       print "    --isregexp                      Whether to treat name, blacklist and whitelist as regexp\n";
       print "-w, --warning=<threshold>           Warning threshold.\n";
       print "-c, --critical=<threshold>          Critical threshold.\n";
       print "                                    Thresholds should be either a simple counter or a percentage\n";
       print "                                    value in the n% (i.e. 90%). If checking more than a single\n";
       print "                                    with --usedspace volume only percent is allowed as threshold or\n";
       print "                                    --spaceleft must be used.\n";
       print "    --spaceleft                     This has to be used in conjunction with thresholds as mentioned above.\n";
       print "                                    The thresholds must be specified as the space left on device and with the\n";
       print "                                    same unit (MB or GB).\n";
       print "\n";
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_cpu_info
    {
    my ($host) = @_;
    my $state = 0;
    my $output;
    my $host_view;
    my $value;
    my $perf_val_error = 1;      # Used as a flag when getting all the values 
                                 # with one call won't work.
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    $values = return_host_performance_values($host,'cpu', ('wait.summation:*','ready.summation:*', 'usage.average'));
        
    if (defined($values))
       {
       $perf_val_error = 0;
       }
       
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }

    if (($subselect eq "wait") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_performance_values($host,'cpu', ('wait.summation:*'));
          }

       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value));
          if ($subselect eq "all")
             {
             $output = "CPU wait=" . $value . " ms";
             $perfdata = "\'cpu_wait\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $output = "CPU wait=" . $value . " ms";
             $perfdata ="\'cpu_wait\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          }
       else
          {
          $actual_state = 3;
          $output = "CPU wait=Not available";
          $state = check_state($state, $actual_state);
          }
       }

    if (($subselect eq "ready") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_performance_values($host,'cpu', ('ready.summation:*'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value));
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][1]->value));
             }

          if ($subselect eq "all")
             {
             $output = $output . " - CPU ready=" . $value . " ms";
             $perfdata = $perfdata . " \'cpu_ready\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $output = "CPU ready=" . $value . " ms";
             $perfdata = "\'cpu_ready\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - CPU ready=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "CPU ready=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_performance_values($host,'cpu', ('usage.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) * 0.01);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][2]->value) * 0.01);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - CPU usage=" . $value . "%"; 
             $perfdata = $perfdata . " \'cpu_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "CPU usage=" . $value . "%"; 
             $perfdata = "\'cpu_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - CPU usage=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "CPU usage=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST CPU subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_disk_io_info
    {
    my ($host) = @_;
    my $value;
    my $state = 0;
    my $output;
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    $values = return_host_performance_values($host, 'disk', ('commandsAborted.summation:*', 'busResets.summation:*', 'read.average:*', 'totalReadLatency.average:*', 'write.average:*', 'totalWriteLatency.average:*', 'usage.average:*', 'kernelLatency.average:*', 'deviceLatency.average:*', 'queueLatency.average:*', 'totalLatency.average:*'));

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ($perf_thresholds ne ';')
          {
          print_help();
          print "\nERROR! Thresholds only allowed with subselects!\n\n";
          exit 2;
          }
       }

    if (($subselect eq "aborted") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value), 0);
          if ($subselect eq "all")
             {
             $output = "I/O commands aborted=" . $value;
             $perfdata = "\'io_aborted\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "io commands aborted=" . $value;
             $perfdata = "\'io_aborted\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "I/O commands aborted=Not available";
          $state = check_state($state, $actual_state);
          }
       }

    if (($subselect eq "resets") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][1]->value), 0);
          if ($subselect eq "all")
             {
             $output =  $output . " - I/O bus resets=" . $value;
             $perfdata = $perfdata . " \'io_busresets\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O bus resets=" . $value;
             $perfdata = "\'io_busresets\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O bus resets=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O bus resets=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "read") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][2]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O read=" . $value . " KB/sec.";
             $perfdata = $perfdata . " \'io_read\'=" . $value . "KB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O read=" . $value . " KB/sec.";
             $perfdata = "\'io_read\'=" . $value . "KB;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O read=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O read=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "read_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][3]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O read latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_read_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O read latency=" . $value . " ms";
             $perfdata = "\'io_read_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O read latency=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O read latency=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "write") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][4]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O write=" . $value . " KB/sec.";
             $perfdata = $perfdata . " \'io_write\'=" . $value . "KB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O write=" . $value . " KB/sec.";
             $perfdata = "\'io_write\'=" . $value . "KB;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O write=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O write=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "write_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][5]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . "I/O write latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_write_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O write latency=" . $value . " ms";
             $perfdata = "\'io_write_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O write latency==Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O write latency==Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][6]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O usage=" . $value . " KB/sec.";
             $perfdata = $perfdata . " \'io_usage\'=" . $value . "KB;;;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O usage=" . $value . " KB/sec., ";
             $perfdata = "\'io_usage\'=" . $value . "KB;;;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O usage=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O usage=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "kernel_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][7]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O kernel latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_kernel_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O kernel latency=" . $value . " ms";
             $perfdata = "\'io_kernel_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O kernel latency=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O kernel latency=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "device_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][8]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O device latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_device_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O device latency=" . $value . " ms";
             $perfdata = "\'io_device_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O device latency=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O device latency=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "queue_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][9]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O queue latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_queue_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O queue latency=" . $value . " ms";
             $perfdata = "\'io_queue_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O queue latency=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O queue latency=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "total_latency") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][10]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O total latency=" . $value . " ms";
             $perfdata = $perfdata . " \'io_total_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O total latency=" . $value . " ms";
             $perfdata = "\'io_total_latency\'=" . $value . "ms;" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O total latency=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O total latency=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST IO subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_list_vm_volumes_info
    {
    my ($host) = @_;
    my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'datastore', 'runtime.inMaintenanceMode']);

    if (!defined($host_view))
       {
       print "Host " . $$host{"name"} . " does not exist\n";
       exit 2;
       }

    if (($host_view->get_property('runtime.inMaintenanceMode')) eq "true")
       {
       print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
       exit 1;
       }

    if (!defined($host_view->datastore))
       {
       print "Insufficient rights to access Datastores on the Host\n";
       exit 2;
       }

    return datastore_volumes_info($host_view->datastore);
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_mem_info
    {
    my ($host) = @_;
    my $state = 0;
    my $output;
    my $value;
    my $vm;
    my $host_view;
    my $vm_view;
    my $vm_views;
    my @vms = ();
    my $index;
    my $perf_val_error = 1;      # Used as a flag when getting all the values 
                                 # with one call won't work.
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect
    
    ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'usage.average', 'consumed.average','swapused.average', 'overhead.average', 'vmmemctl.average'));
        
    if (defined($values))
       {
       $perf_val_error = 0;
       }
       
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ($perf_thresholds ne ';')
          {
          print_help();
          print "\nERROR! Thresholds only allowed with subselects!\n\n";
          exit 2;
          }
       }

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'usage.average'));
          }

       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value) * 0.01);
          if ($subselect eq "all")
             {
             $output = "mem usage=" . $value . "%"; 
             $perfdata = "\'mem_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "mem usage=" . $value . "%"; 
             $perfdata = "\'mem_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "mem usage=Not available"; 
          $state = check_state($state, $actual_state);
          }
       }
       
    if (($subselect eq "consumed") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'consumed.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][1]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - consumed memory=" . $value . " MB";
             $perfdata = $perfdata . " \'consumed_memory\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "consumed memory=" . $value . " MB";
             $perfdata = "\'consumed_memory\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - consumed memory=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "consumed memory=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "swapused") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'swapused.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][2]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - swap used=" . $value . " MB";
             $perfdata = $perfdata . " \'mem_swap\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "swap used=" . $value . " MB";
             $perfdata = "\'mem_swap\'=" . $value . "MB;" . $perf_thresholds . ";;";

             if ($actual_state != 0)
                {
                $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $$host_view[0], properties => ['name', 'runtime.powerState']);
   
                if (defined($vm_views))
                   {
                   if (@$vm_views)
                      {
                      @vms = ();
                      foreach $vm (@$vm_views)
                              {
                              if ($vm->get_property('runtime.powerState')->val eq "poweredOn")
                                 {
                                 push(@vms, $vm);
                                 }
                              }
                   
                      $values = generic_performance_values(\@vms, 'mem', ('swapped.average'));
                      if (defined($values))
                         {
                         foreach $index (0..@vms-1)
                                 {
                                 $value = simplify_number(convert_number($$values[$index][0]->value) / 1024);
                                 if ($value > 0)
                                    {
                                    if ($value > 0)
                                       {
                                       $output = $output . $multiline . $vms[$index]->name . " (" . $value . "MB)";
                                       }
                                    }
                                 }
                         }
                      }
      
                   }
                }
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - swap used=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "swap used=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "overhead") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'overhead.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][3]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - overhead=" . $value . " MB";
             $perfdata = $perfdata . " \'mem_overhead\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "overhead=" . $value . " MB";
             $perfdata = "\'mem_overhead\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - mem overhead=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "mem overhead=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "memctl") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          ($host_view, $values) = return_host_performance_values($host, 'mem', ( 'vmmemctl.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][4]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - memctl=" . $value . " MB: ";
             $perfdata = $perfdata . " \'mem_memctl\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "memctl=" . $value . " MB";
             $perfdata = "\'mem_memctl\'=" . $value . "MB;" . $perf_thresholds . ";;";

             if ($actual_state != 0)
                {
                $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $$host_view[0], properties => ['name', 'runtime.powerState']);
   
                if (defined($vm_views))
                   {
                   if (@$vm_views)
                      {
                      foreach $vm (@$vm_views)
                              {
                              if ($vm->get_property('runtime.powerState')->val eq "poweredOn")
                                 {
                                 push(@vms, $vm);
                                 }
                              }
                      $values = generic_performance_values(\@vms, 'mem', ('vmmemctl.average'));
         
                      if (defined($values))
                         {
                         foreach $index (0..@vms-1)
                                 {
                                 $value = simplify_number(convert_number($$values[$index][0]->value) / 1024);
                                 if ($value > 0)
                                    {
                                    $output = $output . $multiline . $vms[$index]->name . " (" . $value . "MB)";
                                    }
                                 }
                         }
                      }
                   }
                }
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - memctl=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "memctl=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST MEM subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_mounted_media_info
    {
    my ($host) = @_;
    my $count = 0;
    my $state;
    my $output;
    my $host_view;
    my $vm_views;
    my $vm;
    my $istemplate;
    my $match;
    my $displayname;
    my $devices;
   
    $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'runtime.inMaintenanceMode']);
    if (!defined($host_view))
       {
       print "Host " . $$host{"name"} . " does not exist\n";
       exit 2;
       }

    if (($host_view->get_property('runtime.inMaintenanceMode')) eq "true")
       {
       print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
       exit 0;
       }

    $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $host_view, properties => ['name', 'config.template', 'config.hardware.device', 'runtime.powerState']);

    if (!defined($vm_views))
       {
       print "Runtime error\n";
       exit 2;
       }
    $output = '';
      
    foreach $vm (@$vm_views)
            {
            # change get_property to {} to avoid infinite loop
            $istemplate = $vm->{'config.template'};
            
            if ($istemplate && ($istemplate eq 'true'))
               {
               next;
               }
            
            $match = 0;
            $displayname = $vm->name;

            if (defined($isregexp))
               {
               $isregexp = 1;
               }
            else
               {
               $isregexp = 0;
               }
               
            if (defined($blacklist))
               {
               if (isblacklisted(\$blacklist, $isregexp, $displayname))
                  {
                  next;
                  }
               }
            if (defined($whitelist))
               {
               if (isnotwhitelisted(\$whitelist, $isregexp, $displayname))
                  {
                  next;
                  }
               }
            $devices = $vm->{'config.hardware.device'};
            foreach $dev (@$devices)
                    {
                    if ((ref($dev) eq "VirtualCdrom") && ($dev->connectable->connected == 1))
                       {
                       $match++;
                       }
                    if ((ref($dev) eq "VirtualFloppy") && ($dev->connectable->connected == 1))
                       {
                       $match++;
                       }
                    }
            if ($match)
               {
               $multiline = "<br>";
               $count++;
               $output = "$displayname(Hits: $match)" . $multiline . $output;
               }
               else
               {
               if ($listall)
                  {
                  $output = $output . "$displayname(Hits: $match)" . $multiline;
                  }
               }
            }

    #Cut the last multiline of $output. Second line is better than 2 time chop() like the original :-)
    if ($output ne '')
       {
       $output  =~ s/<br>$//i;
       $output  =~ s/\n$//i;
       }

    if ($count)
       {
       $output = "VMs mounted host media devices (floppy, cd or dvd):" . $multiline . $output;
       $state = 1;
       }
    else
       {
       if ($listall)
          {
          $output = "No VMs with mounted host media devices (floppy, cd or dvd) found VMs." . $multiline . $output;
          }
       else
          {
          $output = "No VMs with mounted host media devices (floppy, cd or dvd) found.";
          }
       $state = 0;
       }

    return ($state, $output);
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
# Notice for further development of this module:
# - more information about the nics

sub host_net_info
    {
    my ($host) = @_;
    my $state = 0;
    my $value;
    my $output;
    my $output_nic = "";
    my $host_view;
    my $network_system;
    my $network_config;
    my $ignored = 0;             # Counter for blacklisted items
    my $OKCount = 0;
    my $BadCount = 0;
    my $TotalCount = 0;
    my @switches = ();
    my $switch;
    my $nic_key;
    my %NIC = ();
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect
        
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       
       if ( $perf_thresholds ne ";")
          {
          print "Error! Thresholds are only allowed with subselects!\n";
          exit 3;
          }
       }

    $values = return_host_performance_values($host, 'net', ('usage.average', 'received.average', 'transmitted.average'));


    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value));
          if ($subselect eq "all")
             {
             $output = "net usage=" . $value . " KBps";
             $perfdata = "\'net_usage\'=" . $value . ";". $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net usage=" . $value . " KBps";
             $perfdata = "\'net_usage\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "net usage=Not available";
          $state = check_state($state, $actual_state);
          }
       }
   
    if (($subselect eq "receive") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][1]->value));
          if ($subselect eq "all")
             {
             $output = $output . " net receive=" . $value . " KBps";
             $perfdata = $perfdata . " \'net_receive\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net receive=" . $value . " KBps";
             $perfdata = "\'net_receive\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " net receive=Not available"; 
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "net receive=Not available"; 
             $state = check_state($state, $actual_state);
             }
          }
       }
  
    if (($subselect eq "send") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][2]->value));
          if ($subselect eq "all")
             {
             $output =$output . ", net send=" . $value . " KBps"; 
             $perfdata = $perfdata . " \'net_send\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net send=" . $value . " KBps"; 
             $perfdata = "\'net_send\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output =$output . ", net send=Not available"; 
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "net send=Not available"; 
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "nic") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'configManager.networkSystem', 'runtime.inMaintenanceMode']);

       if (!defined($host_view))
          {
          print "Host " . $$host{"name"} . " does not exist\n";
          exit 2;
          }
       
       if (uc($host_view->get_property('runtime.inMaintenanceMode')) eq "TRUE")
          {
          print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
          exit 0;
          }
 
       $network_system = Vim::get_view(mo_ref => $host_view->get_property('configManager.networkSystem') , properties => ['networkInfo']);
       $network_system->update_view_data(['networkInfo']);
       $network_config = $network_system->networkInfo;

       if (!defined($network_config))
          {
          print "Host " . $$host{"name"} . " has no network info in the API.\n";
          exit 2;
          }

       # create a hash of NIC info to facilitate easy lookups
       foreach (@{$network_config->pnic})
               {
               $NIC{$_->key} = $_;
               $TotalCount++;
               }

       if (exists($network_config->{vswitch}))
          {
          push(@switches, $network_config->vswitch);
          }
       if (exists($network_config->{proxySwitch}))
          {
          push(@switches, $network_config->proxySwitch);
          }

       # see which NICs are actively part of a switch
       foreach $switch (@switches)
               {
               foreach (@{$switch})
                       {
                       # get list of physical nics
                       if (defined($_->pnic))
                          {
                          foreach $nic_key (@{$_->pnic})
                                  {
                                  if (defined($isregexp))
                                     {
                                     $isregexp = 1;
                                     }
                                  else
                                     {
                                     $isregexp = 0;
                                     }
                                     
                                  if (defined($blacklist))
                                     {
                                     if (isblacklisted(\$blacklist, $isregexp, $NIC{$nic_key}->device))
                                        {
                                        $ignored++;
                                        next;
                                        }
                                     }
                   
                                  if (!defined($NIC{$nic_key}->linkSpeed))
                                     {
                                     if ($output_nic)
                                        {
                                        $output_nic = $output_nic . ", ";
                                        }
                                     $output_nic = $output_nic . $multiline . $NIC{$nic_key}->device . " is unplugged";
                                     $state = 1;
                                     $BadCount++;
                                     }
                                  else
                                     {
                                     $output_nic = $output_nic . $multiline . $NIC{$nic_key}->device . " is ok";
                                     $OKCount++;
                                     }
                                  }
                          }
                       }
               }

        if ($subselect ne "all")
           {
           $output = "NICs total:" . $TotalCount . " NICs attached to switch:" . ($OKCount + $BadCount) . " NICs connected:" . $OKCount . " NICs disconnected:" . $BadCount . " NICs ignored:" . $ignored . $output_nic;
           }
        else
           {
           $output = $output . " NICs total:" . $TotalCount . " NICs attached to switch:" . ($OKCount + $BadCount) . " NICs connected:" . $OKCount . " NICs disconnected:" . $BadCount . " NICs ignored:" . $ignored;
           }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST NET subselect");
       }
    else
       {
       return ($state, $output);
       }
   }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_runtime_info
    {
    my ($host) = @_;
    my $charging;
    my $summary;
    my $sensorname;
    my $state = 0;
    my $actual_state;
    my $output = '';
    my $runtime;
    my $host_view;
    my %base_units = (
                     'Degrees C' => 'C',
                     'Degrees F' => 'F',
                     'Degrees K' => 'K',
                     'Volts' => 'V',
                     'Amps' => 'A',
                     'Watts' => 'W',
                     'Percentage' => 'Pct'
                     );
    my $components = {};
    my $cpuStatusInfo;
    my $curstate;
    my $fstate;
    my %host_maintenance_state;
    my $issues;
    my $issue_out = '';
    my $issue_cnt = 0;
    my $issues_ignored_cnt = 0;
    my $issues_alarm_cnt = 0;
    my $itemref;
    my $item_ref;
    my $memoryStatusInfo;
    my $name;
    my $numericSensorInfo;;
    my $OKCount;
    my $SensorCount;
    my $status;
    my $storageStatusInfo;;
    my $type;
    my $unit;
    my $poweredon = 0;         # Virtual machine powerstate
    my $poweredoff = 0;        # Virtual machine powerstate
    my $suspended = 0;         # Virtual machine powerstate
    my $poweredon_out = '';    # Virtual machine powerstate temporary output
    my $poweredoff_out = '';   # Virtual machine powerstate temporary output
    my $suspended_out = '';    # Virtual machine powerstate temporary output
    my $value;
    my $vm;
    my $vm_state;
    my $vm_views;
    my $true_sub_sel=1;        # Just a flag. To have only one return at the en
                               # we must ensure that we had a valid subselect. If
                               # no subselect is given we select all
                               # 0 -> existing subselect
                               # 1 -> non existing subselect

    if ((!defined($subselect)) || ($subselect eq "health"))
       {
       if ( $perf_thresholds ne ";")
          {
          print "Error! Thresholds are only allowed with subselects but ";
          print "not with --subselect=health !\n";
          exit 2;
          }
       }

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }


    if ((defined($listsensors)) && ($subselect ne "health"))
       {
       print "Error! --listsensors only allowed whith -s health!\n";
       exit 2;
       }
       
    $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'runtime', 'overallStatus', 'configIssue']);

    if (!defined($host_view))
       {
       print "Host " . $$host{"name"} . " does not exist\n";
       exit 2;
       }

    $host_view->update_view_data(['name', 'runtime', 'overallStatus', 'configIssue']);
    $runtime = $host_view->runtime;

    if ($runtime->inMaintenanceMode)
       {
       print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
       exit 1;
       }

    if (($subselect eq "listvms") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (!defined($vm_tools_poweredon_only))
          {
          $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $host_view, properties => ['name', 'runtime']);
          }
       else
          {
          $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', filter => {'runtime.powerState' => 'poweredOn'}, begin_entity => $host_view, properties => ['name', 'runtime']);
          }

       if (!defined($vm_views))
          {
          print "Runtime error\n";
          exit 2;
          }
       if (!@$vm_views)
          {
          if ($subselect eq "all")
             {
             $output = $output . "No VMs - ";
             }
          else
             {
             $output = "No VMs - ";
             }
          }
       else
          {
          foreach $vm (@$vm_views)
                  {
                  if (defined($isregexp))
                     {
                     $isregexp = 1;
                     }
                  else
                     {
                     $isregexp = 0;
                     }
               
                  if (defined($blacklist))
                     {
                     if (isblacklisted(\$blacklist, $isregexp, $vm->name))
                        {
                        next;
                        }
                     }
                  if (defined($whitelist))
                     {
                     if (isnotwhitelisted(\$whitelist, $isregexp, $vm->name))
                        {
                        next;
                        }
                      }

                  $vm_state = $vm->runtime->powerState->val;
               
                  if ($vm_state eq "poweredOn")
                     {
                     $poweredon++;
                     $poweredon_out = $poweredon_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                     }
                  if ($vm_state eq "poweredOff")
                     {
                     $poweredoff++;
                     $poweredoff_out = $poweredoff_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                     }
                  if ($vm_state eq "suspended")
                     {
                     $suspended++;
                     $suspended_out = $suspended_out . $vm->name . " (" . $vm_state . ")" . $multiline;
                     }
                  }

          if ($subselect eq "all")
             {
             $output = $suspended . "/" . @$vm_views . " VMs suspended - ";
             $output = $output . $poweredoff . "/" . @$vm_views . " VMs powered off - ";
             $output = $output . $poweredon . "/" . @$vm_views . " VMs powered on - ";
             }
          else
             {
             $output = $suspended . "/" . @$vm_views . " VMs suspended - ";
             $output = $output . $poweredoff . "/" . @$vm_views . " VMs powered off - ";
             $output = $output . $poweredon . "/" . @$vm_views . " VMs powered on." . $multiline;
             $output = $output . $suspended_out . $poweredoff_out . $poweredon_out;
             $perfdata = "vms_total=" .  @$vm_views . ";;;; vms_poweredon=" . $poweredon . ";;;; vms_poweredoff=" . $poweredoff . ";;;; vms_suspended=" . $suspended . ";;;;";
             }
          }
       }

    if (($subselect eq "status") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $status = $host_view->overallStatus->val;
       if ($subselect eq "all")
          {
          $output = $output . "overallstatus=" . $status;
          }
       else
          {
          $output = "overall status=" . $status;
          }
       $state = check_health_state($status);
       }

    if (($subselect eq "con") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if (lc($runtime->connectionState->val) eq "disconnected")
          {
          $state = 1;
          }
       if (lc($runtime->connectionState->val) eq "notResponding")
          {
          $state = 2;
          }

       if ($subselect eq "all")
          {
          $output = $output . " - connection state=" . $runtime->connectionState->val;
          }
       else
          {
          $output = "connection state=" . $runtime->connectionState->val;
          }
       }

    if (($subselect eq "health") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $OKCount = 0;
       $AlertCount = 0;

       if (defined($runtime->healthSystemRuntime))
          {
          $cpuStatusInfo = $runtime->healthSystemRuntime->hardwareStatusInfo->cpuStatusInfo;
          $storageStatusInfo = $runtime->healthSystemRuntime->hardwareStatusInfo->storageStatusInfo;
          $memoryStatusInfo = $runtime->healthSystemRuntime->hardwareStatusInfo->memoryStatusInfo;
          $numericSensorInfo = $runtime->healthSystemRuntime->systemHealthInfo->numericSensorInfo;

          if (defined($cpuStatusInfo))
             {
             foreach (@$cpuStatusInfo)
                     {
                     $actual_state = check_health_state($_->status->key);

                     # Ejection seat for not running CIM Server
                     if ($actual_state == 3)
                        {
                        print "Critical! No result from CIM server.CIM server is probably not running or not running correctly! Please restart!\n";
                        exit 2;
                        }
                        
                     $itemref = {
                                name => $_->name,
                                summary => $_->status->summary
                                };
                     push(@{$components->{$actual_state}{CPU}}, $itemref);
                     if ($actual_state != 0)
                        {
                        $state = check_state($state, $actual_state);
                        $AlertCount++;
                        }
                     else
                        {
                        $OKCount++;
                        }
                     }
             }

          if (!defined($nostoragestatus))
             {
             if (defined($storageStatusInfo))
                {
                foreach (@$storageStatusInfo)
                        {
                        if (defined($isregexp))
                           {
                           $isregexp = 1;
                           }
                        else
                           {
                           $isregexp = 0;
                           }
                  
                        if (defined($blacklist))
                           {
                           if (isblacklisted(\$blacklist, $isregexp, $_->name, "Storage"))
                              {
                              next;
                              }
                           }
     
                        if (defined($whitelist))
                           {
                           if (isnotwhitelisted(\$whitelist, $isregexp, $_->name, "Storage"))
                              {
                              next;
                              }
                           }
   
                        $actual_state = check_health_state($_->status->key);
                        $itemref = {
                                   name => $_->name,
                                   summary => $_->status->summary
                                   };
                        push(@{$components->{$actual_state}{Storage}}, $itemref);
                        
                        if ($actual_state != 0)
                           {
                           $state = check_state($state, $actual_state);
                           $AlertCount++;
                           }
                        else
                           {
                           $OKCount++;
                           }
                        }
                }
             }

          if (defined($memoryStatusInfo))
             {
             foreach (@$memoryStatusInfo)
                     {
                     if (defined($isregexp))
                        {
                        $isregexp = 1;
                        }
                     else
                        {
                        $isregexp = 0;
                        }
               
                     if (defined($blacklist))
                        {
                        if (isblacklisted(\$blacklist, $isregexp, $_->name, "Memory"))
                           {
                           next;
                           }
                        }
  
                     if (defined($whitelist))
                        {
                        if (isnotwhitelisted(\$whitelist, $isregexp, $_->name, "Memory"))
                           {
                           next;
                           }
                        }
                     
                     $actual_state = check_health_state($_->status->key);
                     $itemref = {
                                name => $_->name,
                                summary => $_->status->summary
                                };
                     push(@{$components->{$actual_state}{Memory}}, $itemref);
                     
                     if ($actual_state != 0)
                        {
                        $state = check_state($state, $actual_state);
                        $AlertCount++;
                        }
                     else
                        {
                        $OKCount++;
                        }
                     }
             }

          if (defined($numericSensorInfo))
             {
             foreach (@$numericSensorInfo)
                     {
                     # Just for debugging. comment it out and see what happens :-))
                     #print "Debug: Sensor Name = ". $_->name;
                     #print ", Type = " . $_->sensorType;
                     #print ", Label = ". $_->healthState->label;
                     #print ", Summary = ". $_->healthState->summary;
                     #print ", Key = " . $_->healthState->key;
                     #print ", Current Reading = " . $_->currentReading;
                     #print ", Unit Modifier = " . $_->unitModifier;
                     #print ", Baseunits  = " . $_->baseUnits . "\n";
                    
                     # Filter out software components. Doesn't make sense here
                     if ( $_->sensorType eq "Software Components" )
                        {
                        next;
                        }

                     # Filter out sensors which have not valid data. Often a sensor is reckognized by vmware 
                     # but has not the ability to report something senseful. So it can be skipped.
                     if (( $_->healthState->label =~ m/unknown/i ) && ( $_->healthState->summary  =~ m/Cannot report/i ))
                        {
                        next;
                        }

                     if (defined($isregexp))
                        {
                        $isregexp = 1;
                        }
                     else
                        {
                        $isregexp = 0;
                        }
               
                     if (defined($blacklist))
                        {
                        if (isblacklisted(\$blacklist, $isregexp, $_->name, $_->sensorType))
                           {
                           next;
                           }
                        }
  
                     if (defined($whitelist))
                        {
                        if (isnotwhitelisted(\$whitelist, $isregexp, $_->name, $_->sensorType))
                           {
                           next;
                           }
                     }
                     
                     $actual_state = check_health_state($_->healthState->key);
                     $itemref = {
                                name => $_->name,
                                summary => $_->healthState->summary,
                                label => $_->healthState->label
                                };
                     push(@{$components->{$actual_state}{$_->sensorType}}, $itemref);
                     
                     if ($actual_state != 0)
                        {
                        if (($actual_state == 3) && (!defined($ignoreunknown)))
                           {
                           # Trouble with the unknown status with sensors should better be a warning than unknown
                           $actual_state = 1;
                           }
                        $state = check_state($state, $actual_state);
                        $AlertCount++;
                        }
                     else
                        {
                        $OKCount++;
                        }
                     }
             }

          if ($listsensors)
             {
             foreach $fstate (reverse(sort(keys(%$components))))
                     {
                     foreach $actual_state_ref ($components->{$fstate})
                             {
                             foreach $type (keys(%$actual_state_ref))
                                     {
                                     foreach $item_ref (@{$actual_state_ref->{$type}})
                                             {
                                             $output = $output . "[$status2text{$fstate}] [Type: $type] [Name: $item_ref->{name}] [Label: $item_ref->{label}] [Summary: $item_ref->{summary}]$multiline";
                                             }
                                     }
                             }
                     }
             }
          else
             {
             # From here on perform output of health
             if ($AlertCount > 0)
                {
                if ($subselect eq "all")
                   {
                   $output = $output . " - $AlertCount health issue(s) found in " . ($AlertCount + $OKCount) . " checks";
                   }
                else
                   {
                   $output = "$AlertCount health issue(s) found in " . ($AlertCount + $OKCount) . " checks: ";
                   }
                
                $AlertIndex = 0;
                
                if ($subselect ne "all")
                   {
                   foreach $fstate (reverse(sort(keys(%$components))))
                           {
                           if ($fstate == 0)
                              {
                              next;
                              }
                           foreach $actual_state_ref ( $components->{$fstate})
                                   {
                                   foreach $type ( keys(%$actual_state_ref))
                                           {
                                           foreach $item_ref (@{$actual_state_ref->{$type}})
                                                   {
                                                   if (!$item_ref->{name})
                                                      {
                                                      $item_ref->{name} = "Unknown";
                                                      }
                                                   if (!$item_ref->{label})
                                                      {
                                                      $item_ref->{label} = "Unknown";
                                                      }
                                                   if (!$item_ref->{summary})
                                                      {
                                                      $item_ref->{summary} = "Unknown";
                                                      }
                                                   $output = $output . ++$AlertIndex . ") [$status2text{$fstate}] [Type: $type] [Name: $item_ref->{name}] [Label: $item_ref->{label}] [Summary: $item_ref->{summary}]$multiline";
                                                   }
                                           }
                                   }
                           }
                   }
                }
             else
                {
                if ($subselect eq "all")
                   {
                   $output = $output . " - All $OKCount health checks are GREEN:";
                   }
                else
                   {
                   $output = "All $OKCount health checks are GREEN:";
                   }
                $actual_state = 0;
                $state = check_state($state, $actual_state);
                foreach $type (keys(%{$components->{0}}))
                        {
                        $output = $output . " " . $type . " (" . (scalar(@{$components->{0}{$type}})) . "x),";
                        }
                chop ($output);
                }
             }
          }
       else
          {
          $output = "System health status unavailable";
          }
       }

    if ($subselect eq "storagehealth")
       {
       $OKCount = 0;
       $AlertCount = 0;
       $components = {};
       $state = 3;

       if(defined($runtime->healthSystemRuntime) && defined($runtime->healthSystemRuntime->hardwareStatusInfo->storageStatusInfo))
         {
         $storageStatusInfo = $runtime->healthSystemRuntime->hardwareStatusInfo->storageStatusInfo;
         $output = '';
         foreach (@$storageStatusInfo)
                 {
                 if (defined($isregexp))
                    {
                    $isregexp = 1;
                    }
                 else
                    {
                    $isregexp = 0;
                    }
               
                if (defined($blacklist))
                   {
                   if (isblacklisted(\$blacklist, $isregexp, $_->name))
                      {
                      next;
                      }
                   }
                if (defined($whitelist))
                   {
                   if (isnotwhitelisted(\$whitelist, $isregexp, $_->name))
                      {
                      next;
                      }
                }
                 
                $actual_state = check_health_state($_->status->key);
                $sensortype = $_->name;
                $components->{$actual_state}{"Storage"}{$_->name} = $_->status->summary;
                 
                if ($actual_state != 0)
                   {
                   $state = check_state($state, $actual_state);
                   $AlertCount++;
                   }
                else
                   {
                   $OKCount++;
                   }
                }

                foreach $fstate (reverse(sort(keys(%$components))))
                        {
                        foreach $actual_state_ref ($components->{$fstate})
                                {
                                foreach $type (keys(%$actual_state_ref))
                                        {
                                        foreach $name (keys(%{$actual_state_ref->{$type}}))
                                                {
                                                $output = $output . "$status2text{$fstate}: Status of $name: $actual_state_ref->{$type}{$name}$multiline";
                                                }
                                        }
                                }
                        }

                if ($AlertCount > 0)
                   {
                   $output = "$AlertCount health issue(s) found. $multiline" . $output;
                   }
                else
                   {
                   $output = "All $OKCount Storage health checks are GREEN. $multiline" . $output;
                   $state = 0;
                   }
         }
      else
         {
         $state = 3;
         $output = "Storage health status unavailable";
         }
       return ($state, $output);
       }

    if ($subselect eq "temp")
       {
       $OKCount = 0;
       $AlertCount = 0;
       $components = {};
       $state = 3;

       if (defined($runtime->healthSystemRuntime))
          {
          $numericSensorInfo = $runtime->healthSystemRuntime->systemHealthInfo->numericSensorInfo;
          $output = '';

          if (defined($numericSensorInfo))
             {
             foreach (@$numericSensorInfo)
                     {
                     if (lc($_->sensorType) ne 'temperature')
                        {
                        next;
                        }
                     
                     if (defined($isregexp))
                        {
                        $isregexp = 1;
                        }
                     else
                        {
                        $isregexp = 0;
                        }
               
                     if (defined($blacklist))
                        {
                        if (isblacklisted(\$blacklist, $isregexp, $_->name))
                           {
                           next;
                           }
                        }
                     if (defined($whitelist))
                        {
                        if (isnotwhitelisted(\$whitelist, $isregexp, $_->name))
                           {
                           next;
                           }
                        }
                     
                     $actual_state = check_health_state($_->healthState->key);
                     $_->name =~ m/(.*?)\s-.*$/;
                     $itemref = {
                                name => $1,
                                power10 => $_->unitModifier,
                                state => $_->healthState->key,
                                value => $_->currentReading,
                                unit => $_->baseUnits,
                                };
                     push(@{$components->{$actual_state}}, $itemref);
                     if ($actual_state != 0)
                        {
                        $state = check_state($state, $actual_state);
                        $AlertCount++;
                        }
                     else
                        {
                        $OKCount++;
                        }
                        
                     if (exists($base_units{$itemref->{unit}}))
                        {
                        $perfdata = $perfdata . " \'" . $itemref->{name} . "\'=" . ($itemref->{value} * 10 ** $itemref->{power10}) . $base_units{$itemref->{unit}} . ";;;;";
                        }
                        else
                        {
                        $perfdata = $perfdata . " \'" . $itemref->{name} . "\'=" . ($itemref->{value} * 10 ** $itemref->{power10}) . ";;;;";
                        }
                     }
             }

          foreach $curstate (reverse(sort(keys(%$components))))
                  {
                  foreach $itemref (@{$components->{$curstate}})
                          {
                          $value = $itemref->{value} * 10 ** $itemref->{power10};
                          $unit = exists($base_units{$itemref->{unit}}) ? $base_units{$itemref->{unit}} : '';
                          $name = $itemref->{name};
                          if ($output)
                             {
                             $output = $output . $multiline;
                             }
                          $output = $output . $status2text{$curstate} . ": " . $name . " = " . $value . $unit;
                          }
                  }

               if ($AlertCount > 0)
                  {
                  $output = "$AlertCount temperature issue(s) found.". $multiline . $output;
                  }
               else
                  {
                  $output = "All $OKCount temperature checks are GREEN." . $multiline . $output;
                  $state = 0;
                  }                               
          }
       else
          {
          $output = "Temperature status unavailable";
          }
       return ($state, $output);
       }


    if (($subselect eq "issues") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $issues = $host_view->configIssue;
       $actual_state = 0;

       if (defined($issues))
          {
          foreach (@$issues)
                  {
                  $issue_cnt++;
                  if (defined($isregexp))
                      {
                      $isregexp = 1;
                      }
                   else
                      {
                      $isregexp = 0;
                      }
            
                  if (defined($blacklist))
                     {
                     if (isblacklisted(\$blacklist, $isregexp, $_->fullFormattedMessage))
                        {
                        $issues_ignored_cnt++;
                        next;
                        }
                     }
                  if (defined($whitelist))
                     {
                     if (isnotwhitelisted(\$whitelist, $isregexp, $_->fullFormattedMessage))
                        {
                        $issues_ignored_cnt++;
                        next;
                        }
                     }
                  $issue_out = $issue_out . format_issue($_) . $multiline;
                  }
          }

       $issues_alarm_cnt = $issue_cnt - $issues_ignored_cnt;

       if ($issues_alarm_cnt > 0)
          {
          $actual_state = 1;
          }
       else
          {
          $actual_state = 0;
          }
       
       $state = check_state($state, $actual_state);
          
       if ($subselect eq "all")
          {
          $output = $output . " - " . $issue_cnt . " config issues  - " . $issues_ignored_cnt  . " config issues ignored";
          }
       else
          {
          $output = $issue_cnt . " config issues - " . $issues_ignored_cnt  . " config issues ignored" . $multiline . $issue_out;
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST RUNTIME subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_service_info
    {
    my ($host) = @_;
    my $state = 0;
    my $output;
    my $services;
    my $service_name;
    my $service_state;
    my %service_state = (0 => "down", 1 => "up");
    my $service_count = 0;
    my $alert_count = 0;;

    my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'configManager', 'runtime.inMaintenanceMode']);

    if (!defined($host_view))
       {
       print "Host " . $$host{"name"} . " does not exist\n";
       exit 2;
       }

    if (($host_view->get_property('runtime.inMaintenanceMode')) eq "true")
       {
       print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
       exit 0;
       }

    $services = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem, properties => ['serviceInfo'])->serviceInfo->service;

    foreach (@$services)
            {
            $service_name = $_->key;
            $service_state = $_->running;

            if (defined($isregexp))
               {
               $isregexp = 1;
               }
            else
               {
               $isregexp = 0;
               }
               
            if (defined($blacklist))
               {
               if (isblacklisted(\$blacklist, $isregexp, $service_name))
                  {
                  next;
                  }
               }
            if (defined($whitelist))
               {
               if (isnotwhitelisted(\$whitelist, $isregexp, $service_name))
                  {
                  next;
                  }
               }
            $service_count++;
            if ($service_state == 0)
               {
               $state = 2;
               $state = check_state($state, $service_state);
               $alert_count++;
               }
            if (!$output)
               {
               $output = $multiline . $service_name . " (" . $service_state{$service_state} . ")";
               }
            else
               {
               $output = $output . $multiline . $service_name . " (" . $service_state{$service_state} . ")";
               }
            }

    # An alert should only be caused if the selection is more specific.. Otherwise you will have an alert for every
    # b...shit.

    if (!((defined($blacklist)) || (defined($whitelist))))
       {
       $state = 0;
       }
       
    $output = "Checked services:(" . $service_count . ") Services up:(" . ($service_count - $alert_count) . ") Services down:(" . $alert_count . ")" . $output;


    return ($state, $output);
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_storage_info
    {
    my ($host, $blacklist) = @_;
    my $count = 0;                        # Counter for items (adapter,luns etc.)
    my $warn_count = 0;                   # Warning counter for items (adapter,luns etc.)
    my $err_count = 0;                    # Error counter for items (adapter,luns etc.)
    my $ignored = 0;                      # Counter for blacklisted items

    my $state = 0;                        # Return state
    my $actual_state = 0;                 # Return state from the current check. Will be compared with $state
                                          # If higher than $state $state will be set to $actual_state
    my $storage;                          # A pointer to the datastructure deliverd by API call
    my $dev;                              # A pointer to the hostbusadapter data structure
    my $canonicalName;                    # Canonical name of LUN
    my $displayName;                      # The displayName is not a fixed identifier. It is freely configurable
                                          # and should (but this is not a must) be unique. Often the canonicalName
                                          # is part of it. So here we extract the canonicalName and take the
                                          # rest as information.

    my $model;
    my $status;
    my $disc_key;                         # The key of the disc. A string like
                                          # key-vim.host.ScsiDisk-020000000060030057003663801344ae770e1cdda34d6567615241
    my %lun2disc_key;                     # Hold the assignment between the key of the disc and the LUN
    my $no_online = 0;
    my $no_offline = 0;
    my $no_unbound = 0;
    my $no_unknown = 0;
    my $scsi;
    my $scsi_id;                          # Contains the SCSI ID
    my $scsi_id_old = "init";             # Contains the SCSI ID from the previous loop. the string
                                          # "init" is needed for the first loop giving a result.
                                          # A counter won't work here due to the fact than SISI ID can
                                          # be black-/whitelisted
    my $operationState;
    my $adapter;
    my $adapter_long;
    my $mpInfolun;
    my $scsiTopology_adapter;
    my $scsiTopology_adapter_target;
    my $scsiTopology_adapter_target_lun;

    my $path;                             # A pointer to the data structure of the path
    my $pathname;                         # The pathname of a LUN
    my $pathState;                        # The state of the path pathname
    my $multipathState;
    my $WWNN;
    my $WWPN;
    my $path_cnt = 0;                     # Counter for paths
    my $path_warn_cnt = 0;                # Warning counter for paths
    my $path_err_cnt = 0;                 # Error counter for paths
    my $mpath_cnt = 0;                    # Counter for multipaths
    my $mpath_warn_cnt = 0;               # Warning counter for multipaths
    my $mpath_err_cnt = 0;                # Error counter for multipaths
    my $mpath_output = " ";
    my $mpath_tmp_output = " ";
    my $mpath_ok_output = " ";
    my $mpath_error_output = " ";
    my $this_mpath_error = 0;             # Flag.
                                          # 0: ok
                                          # 1: one or more the paths has an error 

    my $output = " ";
    my $lun_ok_output = " ";
    my $lun_warn_output = " ";
    my $lun_error_output = " ";


    my $true_sub_sel=1;                   # Just a flag. To have only one return at the end
                                          # we must ensure that we had a valid subselect. If
                                          # no subselect is given we select all
                                          # 0 -> existing subselect
                                          # 1 -> non existing subselect

    my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => $host, properties => ['name', 'configManager', 'runtime.inMaintenanceMode']);


    if (!defined($host_view))
       {
       print "Host " . $$host{"name"} . " does not exist\n";
       exit 2;
       }

    if (($host_view->get_property('runtime.inMaintenanceMode')) eq "true")
       {
       print "Notice: " . $host_view->name . " is in maintenance mode, check skipped\n";
       exit 1;
       }
   
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }

    $storage = Vim::get_view(mo_ref => $host_view->configManager->storageSystem, properties => ['storageDeviceInfo']);

    if (($subselect eq "adapter") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       foreach $dev (@{$storage->storageDeviceInfo->hostBusAdapter})
               {
               if (defined($isregexp))
                  {
                  $isregexp = 1;
                  }
               else
                  {
                  $isregexp = 0;
                  }

               if (defined($blacklist))
                  {
                  if (isblacklisted(\$blacklist, $isregexp, $dev->device))
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  if (isblacklisted(\$blacklist, $isregexp, $dev->model))
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  if (isblacklisted(\$blacklist, $isregexp, $dev->key))
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  }

                  if (defined($whitelist))
                  {
                  if (isnotwhitelisted(\$whitelist, $isregexp, $dev->device) and
                      isnotwhitelisted(\$whitelist, $isregexp, $dev->model) and
                      isnotwhitelisted(\$whitelist, $isregexp, $dev->key) )
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  }                    
 
               if ($dev->status eq "online")
                  {
                  $count++;
                  $actual_state = 0;
                  $no_online++;
                  $state = check_state($state, $actual_state);
                  }
               if ($dev->status eq "offline")
                  {
                  $count++;
                  $actual_state = 2;
                  $no_offline++;
                  $state = check_state($state, $actual_state);
                  }
               if ($dev->status eq "unbound")
                  {
                  $count++;
                  $actual_state = 1;
                  $no_unbound++;
                  $state = check_state($state, $actual_state);
                  }
               if ($dev->status eq "unknown")
                  {
                  $count++;
                  $actual_state = 3;
                  $no_unknown++;
                  $state = check_state($state, $actual_state);
                  }
               $output = $output . $dev->model . " " . $dev->device . "(" . $dev->status . ")" . $multiline;
               }

       # Remove the leading blank
       $output =~ s/^ //;
       
       if ($subselect eq "all")
          {
          $output = "Adapters:" . $count++ . " Ignored:" . $ignored++ . " Online:" . $no_online . " Offline:" . $no_offline . " Unbound:" . $no_unbound . " Unknown:" . $no_unknown . $multiline;
          }
       else
          {
          $output = "Adapters:" . $count++ . " Ignored:" . $ignored++ . " Online:" . $no_online . " Offline:" . $no_offline . " Unbound:" . $no_unbound . " Unknown:" . $no_unknown . $multiline . $output;
          }
       }


    # Build a hash containing the LUN identifier and the SCSI ID
    if (($subselect eq "lun") || ($subselect eq "path") || ($subselect eq "all"))
       {
       foreach $scsiTopology_adapter (@{$storage->storageDeviceInfo->scsiTopology->adapter})
               {
               if (exists($scsiTopology_adapter->{target}))
                  {
                  foreach $scsiTopology_adapter_target (@{$scsiTopology_adapter->target})
                          {
                          if (exists($scsiTopology_adapter_target->{lun}))
                             {
                             foreach $scsiTopology_adapter_target_lun (@{$scsiTopology_adapter_target->lun})
                                     {
                                     # $scsiTopology_adapter_target_lun->scsiLun is not the LUN. The misleading name
                                     # is a string like
                                     # key-vim.host.ScsiDisk-020000000060030057003663801344ae770e1cdda34d6567615241
                                     # It is the same as storageDeviceInfo->scsiLun->key (see below)
                                     $disc_key = $scsiTopology_adapter_target_lun->scsiLun;
                                     $disc_key =~ s/^.*-//;
                                     $lun2disc_key{$disc_key} = sprintf("%03d", $scsiTopology_adapter_target_lun->lun);
                                     }
                             }
                          }
                  }
               }
       }


    if (($subselect eq "lun") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $ignored = 0;

       foreach $scsi (@{$storage->storageDeviceInfo->scsiLun})
               {
               $canonicalName = $scsi->canonicalName;
               $scsi_id = $scsi->uuid;
               $disc_key = $scsi->key;
               $disc_key =~ s/^.*-//;

               # The displayName is not a fixed identifier. It is freely configurable
               # and should (but this is not a must) be unique. Often the canonicalName is
               # part of it. So here we extract the canonicalName and take the rest as information.
               if (exists($scsi->{displayName}))
                  {
                  $displayName = $scsi->displayName;
                  $displayName =~ s/$canonicalName//;
                  $displayName =~ s/[^\w\s]//g;
                  $displayName =~ s/\s+$//g;
                  $canonicalName = $canonicalName . " (" . $displayName . ")";
                  }

               if (defined($isregexp))
                  {
                  $isregexp = 1;
                  }
               else
                  {
                  $isregexp = 0;
                  }

               if (defined($blacklist))
                  {
                  if (isblacklisted(\$blacklist, $isregexp, $canonicalName))
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  }
               if (defined($whitelist))
                  {
                  if (isnotwhitelisted(\$whitelist, $isregexp, $canonicalName))
                     {
                     $count++;
                     $ignored++;
                     next;
                     }
                  }

               $operationState = join("-", @{$scsi->operationalState});

               foreach (@{$scsi->operationalState})
                       {
                       #       degraded             One or more paths to the LUN are down, but I/O is still possible. Further
                       #                            path failures may result in lost connectivity.
                       #       error                The LUN is dead and/or not reachable.
                       #       lostCommunication    No more paths are available to the LUN.
                       #       off                  The LUN is off.
                       #       ok                   The LUN is on and available.
                       #       quiesced             The LUN is inactive.
                       #       timeout              All Paths have been down for the timeout condition determined by a
                       #                            user-configurable host advanced option.
                       #       unknownState         The LUN state is unknown.
                       if (($_) eq "ok")
                          {
                          $count++;
                          $actual_state = 0;
                          $lun_ok_output = $lun_ok_output . "LUN:" . $lun2disc_key{$disc_key} . " - State: " . $operationState . " - Name: " . $canonicalName . $multiline;
                          }
                       if ((($_) eq "degraded") || (($_) eq "unknownState"))
                          {
                          $count++;
                          $actual_state = 1;
                          $warn_count++;
                          $lun_warn_output = $lun_warn_output . "LUN:" . $lun2disc_key{$disc_key} . " - State: " . $operationState . " - Name: " . $canonicalName . $multiline;
                          }
                       if ((($_) eq "error") || (($_) eq "off") || (($_) eq "quiesced") || (($_) eq "timeout"))
                          {
                          $count++;
                          $actual_state = 2;
                          $err_count++;
                          $lun_error_output = $lun_error_output . "LUN:" . $lun2disc_key{$disc_key} . " - State: " . $operationState . " - Name: " . $canonicalName . $multiline;
                          }
                       $state = check_state($state, $actual_state);
                       }
                 }

       # Remove the leading blank
       $lun_ok_output =~ s/^ //;
       $lun_warn_output =~ s/^ //;
       $lun_error_output =~ s/^ //;

       if ($subselect eq "all")
          {
          $output = $output . " LUNs:" . $count . " - LUNs(ignored):" . $ignored . " - LUNs(warn):" . $warn_count . " - LUNSs(crit):" . $err_count;
          }
       else
          {
          $output = "LUNs:" . $count . " - LUNs(ignored):" . $ignored . " - LUNs(warn):" . $warn_count . " - LUNSs(crit):" . $err_count;
          if (defined($alertonly))
             {
             $output = $output . $multiline . $lun_error_output . $lun_warn_output;
             }
             else
             {
             $output = $output . $multiline . $lun_error_output . $lun_warn_output . $lun_ok_output;
             }
          }
       
       # Remove the last \n or <br>
       $output =~ s/$multiline$//;
       }


    if (($subselect eq "path") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $ignored = 0;

       if (exists($storage->storageDeviceInfo->{multipathInfo}))
          {
          foreach $mpInfolun (@{$storage->storageDeviceInfo->multipathInfo->lun})
                  {
                  foreach $path (@{$mpInfolun->path})
                          {
                          $scsi_id = $path->lun;
                          $scsi_id =~ s/^.*-//;
                          
                          if (defined($isregexp))
                             {
                             $isregexp = 1;
                             }
                          else
                             {
                             $isregexp = 0;
                             }

                          if (defined($blacklist))
                             {
                             if (isblacklisted(\$blacklist, $isregexp, $scsi_id))
                                {
                                if ($scsi_id ne $scsi_id_old)
                                   {
                                   $mpath_cnt++;
                                   $ignored++;
                                   next;
                                   }
                                }
                             }
                          if (defined($whitelist))
                             {
                             if (isnotwhitelisted(\$whitelist, $isregexp, $scsi_id))
                                {
                                if ($scsi_id ne $scsi_id_old)
                                   {
                                   $mpath_cnt++;
                                   $ignored++;
                                   next;
                                   }
                                }
                             }
           
                          if ($scsi_id ne $scsi_id_old)
                             {
                             # If we are here we have a new multipath
                             if ($scsi_id_old ne "init")
                                {
                                # Processing the results of the previous loop
                                if ($this_mpath_error != 0)
                                   {
                                   $mpath_error_output = $mpath_error_output . $mpath_tmp_output . $multiline;
                                   $mpath_error_output =~ s/^ //;
                                   }
                                else
                                   {
                                   $mpath_ok_output = $mpath_ok_output . $mpath_tmp_output . $multiline;
                                   $mpath_ok_output =~ s/^ //;
                                   }
                                }
                             $this_mpath_error = 0;
                             $scsi_id_old = $scsi_id;
                             $mpath_cnt++;
                             $mpath_tmp_output = "LUN:" . $lun2disc_key{$scsi_id} . $multiline;
                             $mpath_tmp_output = $mpath_tmp_output . "SCSI-ID:" . $scsi_id . $multiline;

                             if (exists($path->{state}))
                                {
                                $multipathState = $path->state;
                                if (($multipathState eq "active") || ($multipathState eq "disabled"))
                                   {
                                   $mpath_tmp_output = $mpath_tmp_output . "Mpath State: " . $multipathState . $multiline; 
                                   $actual_state = 0;
                                   $state = check_state($state, $actual_state);
                                   }
                                if ($multipathState eq "dead")
                                   {
                                   $mpath_tmp_output = $mpath_tmp_output . "Mpath State: " . $multipathState . $multiline; 
                                   $actual_state = 2;
                                   $state = check_state($state, $actual_state);
                                   $this_mpath_error = 1;
                                   $mpath_err_cnt++;
                                   }
                                if ($multipathState eq "standby")
                                   {
                                   $mpath_tmp_output = $mpath_tmp_output . "Mpath State: " . $multipathState . $multiline; 
                                   if (defined($standbyok))
                                      {
                                      $actual_state = 0;
                                      $state = check_state($state, $actual_state);
                                      }
                                   else
                                      {
                                      $actual_state = 1;
                                      $state = check_state($state, $actual_state);
                                      $this_mpath_error = 1;
                                      $mpath_warn_cnt++;
                                      }
                                   }
                                if ($multipathState eq "unknown")
                                   {
                                   $mpath_tmp_output = $mpath_tmp_output . "Mpath State: " . $multipathState . $multiline; 
                                   $actual_state = 3;
                                   $state = check_state($state, $actual_state);
                                   $this_mpath_error = 1;
                                   $mpath_unknown_cnt++;
                                   }
                                }
                              }

                          $adapter_long = $path->adapter;
                          $adapter = $adapter_long;
                          $adapter =~ s/^.*-vm/vm/;

                          $mpath_tmp_output = $mpath_tmp_output . "Adapter: " . $adapter;

                          if ($adapter_long =~ m/FibreChannel/i )
                             {
                             $WWNN = $path->transport->nodeWorldWideName;
                             $WWPN = $path->transport->portWorldWideName;
                             $mpath_tmp_output = $mpath_tmp_output . " WWNN: " . $WWNN;
                             $mpath_tmp_output = $mpath_tmp_output . " WWPN: " . $WWPN . $multiline;
                             }
                             else
                             {
                             $mpath_tmp_output = $mpath_tmp_output . $multiline;
                             }

                          $pathname = $path->name;
                          $mpath_tmp_output = $mpath_tmp_output . "Path: " . $pathname;

                          if (exists($path->{pathState}))
                             {
                             $pathState = $path->pathState;
                             $path_cnt++;

                             if (($pathState eq "active") || ($pathState eq "standby") || ($pathState eq "disabled"))
                                {
                                $mpath_tmp_output = $mpath_tmp_output . $multiline . "State: " . $pathState . $multiline; 
                                $actual_state = 0;
                                $state = check_state($state, $actual_state);
                                }
                             if ($pathState eq "dead")
                                {
                                $mpath_tmp_output = $mpath_tmp_output . $multiline . "State: " . $pathState . $multiline; 
                                $actual_state = 2;
                                $state = check_state($state, $actual_state);
                                $this_mpath_error = 1;
                                $path_err_cnt++;
                                }
                             if ($pathState eq "unknown")
                                {
                                $mpath_tmp_output = $mpath_tmp_output . $multiline . "State: " . $pathState . $multiline; 
                                $actual_state = 1;
                                $state = check_state($state, $actual_state);
                                $this_mpath_error = 1;
                                $path_warn_cnt++;
                                }
                             }
                          }
                  }

               if ($this_mpath_error != 0)
                  {
                  $mpath_error_output = $mpath_error_output . $mpath_tmp_output;
                  $mpath_error_output =~ s/^ //;
                  }
               else
                  {
                  $mpath_ok_output = $mpath_ok_output . $mpath_tmp_output;
                  $mpath_ok_output =~ s/^ //;
                  }

            if ($subselect eq "all")
               {
               $output = $output . " Multipaths:" . $mpath_cnt . " - Multipaths(ignored):" . $ignored . " - Multipaths(warn):" . $mpath_warn_cnt . " - Multipaths(error):" . $mpath_err_cnt . " - Paths:" . $path_cnt . " - Paths(warn):" . $path_warn_cnt . " - Paths(error):" . $path_err_cnt;
               }
            else
               {
               $output = "Multipaths:" . $mpath_cnt . " - Multipaths(ignored):" . $ignored . " - Multipaths(warn):" . $mpath_warn_cnt . " - Multipaths(error):" . $mpath_err_cnt . " - Paths:" . $path_cnt . " - Paths(warn):" . $path_warn_cnt . " - Paths(error):" . $path_err_cnt;
               if (defined($alertonly))
                  {
                  $output = $output . $multiline . $mpath_error_output;
                  }
                  else
                  {
                  $output = $output . $multiline . $mpath_error_output . $mpath_ok_output;
                  }
               }
            }
         else
            {
            $output = "Path info is unavailable on this host";
            $state = 3;
            }
         }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown host storage subselect");
       }
    else
       {
#       $output = "miist";
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub host_uptime_info
   {
   my ($host) = @_;
   my $state = 2;
   my $output = 'HOST UPTIME Unknown error';
   my $value;

   $values = return_host_performance_values($host, 'sys', ('uptime.latest'));

   if (defined($values))
      {
      $value = simplify_number(convert_number($$values[0][0]->value), 0);
      }

   if (defined($value))
      {
      $state = 0;
      $output =  "uptime=" . duration_exact($value);
      }
   return ($state, $output);
   }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub get_key_metrices
    {
    my ($perfmgr_view, $group, @names) = @_;

    my $perfCounterInfo = $perfmgr_view->perfCounter;
    my @counters;
    my $cur_name;
    my $index;

    if (!defined($perfCounterInfo))
       {
       print "Insufficient rights to access perfcounters\n";
       exit 2;
       }

    foreach (@$perfCounterInfo)
            {
            if ($_->groupInfo->key eq $group)
               {
               $cur_name = $_->nameInfo->key . "." . $_->rollupType->val;
               foreach $index (0..@names-1)
                       {
                       if ($names[$index] =~ /$cur_name/)
                          {
                          $names[$index] =~ /(\w+).(\w+):*(.*)/;
                          $counters[$index] = PerfMetricId->new(counterId => $_->key, instance => $3);
                          }
                       }
               }
            }

    return \@counters;
    }

sub generic_performance_values
    {
    my ($views, $group, @list) = @_;
    my $amount = @list;
    my $counter = 0;
    my @host_values;
    my $id;
    my $index;
    my $metrices;
    my $perfargs;
    my $perf_interval;
    my $perfMgr = $perfargs->{perfCounter};
    my @perf_query_spec;
    my $unsorted;
    my $perf_data;
    my @values = ();

    if (!defined($perfMgr))
       {
       $perfMgr = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager, properties => [ 'perfCounter' ]);
       $perfargs->{perfCounter} = $perfMgr;
       }
     
    $metrices = get_key_metrices($perfMgr, $group, @list);

    @perf_query_spec = ();

       foreach (@$views)
               {
               push(@perf_query_spec, PerfQuerySpec->new(entity => $_, metricId => $metrices, format => 'csv', intervalId => 20, maxSample => 1));
               }

        $perf_data = $perfMgr->QueryPerf(querySpec => \@perf_query_spec);
        $amount *= @$perf_data;

        while (@$perf_data)
              {
              $unsorted = shift(@$perf_data)->value;
              @host_values = ();

              foreach $id (@$unsorted)
                      {
                      foreach $index (0..@$metrices-1)
                              {
                              if ($id->id->counterId == $$metrices[$index]->counterId)
                                 {
                                 if (!defined($host_values[$index]))
                                    {
                                    $counter++;
                                    }
                                 $host_values[$index] = $id;
                                 }
                              }
                      }
              push(@values, \@host_values);
              }
        if ($counter != $amount || $counter == 0)
           {
           return undef;
           }
        else
           {
           return \@values;
           }
    }

sub return_host_performance_values
    {
    my $values;
    my $host_name = shift(@_);
    my $host_view;

    $host_view = Vim::find_entity_views(view_type => 'HostSystem', filter => $host_name, properties => (['name', 'runtime.inMaintenanceMode']) ); # Added properties named argument.

    if (!defined($host_view))
       {
       print "Runtime error\n";
       exit 2;
       }

    if (!@$host_view)
       {
       print "Host " . $$host_name{"name"} . " does not exist\n";
       exit 2;
       }

    if (($$host_view[0]->get_property('runtime.inMaintenanceMode')) eq "true")
       {
       print "Notice: " . $$host_view[0]->name . " is in maintenance mode, check skipped\n";
       exit 0;
       }

    $values = generic_performance_values($host_view, @_);

    if ($@)
       {
       return undef;
       }
    else
       {
       return ($host_view, $values);
       }
    }

sub return_host_vmware_performance_values
    {
    my $values;
    my $vmname = shift(@_);
    my $vm_view;
        
    $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine', filter => {name => "$vmname"}, properties => [ 'name', 'runtime.powerState' ]);

    if (!defined($vm_view))
       {
       print "Runtime error\n";
       exit 2;
       }

    if (!@$vm_view)
       {
       print "VMware machine " . $vmname . " does not exist\n";
       exit 2;
       }

    if ($$vm_view[0]->get_property('runtime.powerState')->val ne "poweredOn")
       {
       print "VMware machine " . $vmname . " is not running. Current state is " . $$vm_view[0]->get_property('runtime.powerState')->val . "\n";
       exit 2;
       }

    $values = generic_performance_values($vm_view, @_);

    if ($@)
       {
       return $@;
       }
    else
       {
       return ($vm_view, $values);
       }
    }

sub return_cluster_performance_values
    {

    my $values;
    my $cluster_name = shift(@_);
    my $cluster_view; # Added properties named argument.

    $cluster_view = Vim::find_entity_views(view_type => 'ClusterComputeResource', filter => { name => "$cluster_name" }, properties => [ 'name' ]); # Added properties named argument.

    if (!defined($cluster_view))
       {
       print "Runtime error\n";
       exit 2;
       }

    if (!@$cluster_view)
       {
       print "Cluster " . $cluster_name . " does not exist\n";
       exit 2;
       }
        
    $values = generic_performance_values($cluster_view, @_);

    if ($@)
       {
       return undef;
       }
    else
       {
       return ($values);
       }
    }


# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub vm_cpu_info
    {
    my ($vmname) = @_;
    my $state = 0;
    my $output;
    my $value;
    my $perf_val_error = 1;      # Used as a flag when getting all the values 
                                 # with one call won't work.
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect
 
    $values = return_host_vmware_performance_values($vmname,'cpu', ('wait.summation:*','ready.summation:*', 'usage.average'));
        
    if (defined($values))
       {
       $perf_val_error = 0;
       }
       
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }

    if (($subselect eq "wait") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname,'cpu', ('wait.summation:*'));
          }

       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value));
          if ($subselect eq "all")
             {
             $output = "CPU wait=" . $value . " ms";
             $perfdata = "\'cpu_wait\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $output = "CPU wait=" . $value . " ms";
             $perfdata = "\'cpu_wait\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          }
       else
          {
          $actual_state = 3;
          $output = "CPU wait=Not available";
          $state = check_state($state, $actual_state);
          }
       }

    if (($subselect eq "ready") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname,'cpu', ('ready.summation:*'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value));
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][1]->value));
             }

          if ($subselect eq "all")
             {
             $output = $output . " - CPU ready=" . $value . " ms";
             $perfdata = $perfdata . " \'cpu_ready\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          else
             {
             $output = "CPU ready=" . $value . " ms";
             $perfdata = "\'cpu_ready\'=" . $value . "ms;" . $perf_thresholds . ";;";
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - CPU ready=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "CPU ready=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname,'cpu', ('usage.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) * 0.01);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][2]->value) * 0.01);
             }
          if ($subselect eq "all")
             {
             $output = $output . " - CPU usage=" . $value . "%"; 
             $perfdata = $perfdata . " \'cpu_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "CPU usage=" . $value . "%"; 
             $perfdata = "\'cpu_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - CPU usage=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "CPU usage=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown VM CPU subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub vm_disk_io_info
    {
    my ($vmname) = @_;
    my $state = 0;
    my $output;
    my $value;
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    $values = return_host_vmware_performance_values($vmname, 'disk', ('usage.average:*', 'read.average:*', 'write.average:*'));
    
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ($perf_thresholds ne ';')
          {
          print_help();
          print "\nERROR! Thresholds only allowed with subselects!\n\n";
          exit 2;
          }
       }

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value), 0);
          if ($subselect eq "all")
             {
             $output = "I/O usage=" . $value . " KB/s";
             $perfdata = $perfdata . " \'io_usage\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O usage=" . $value . " KB/s";
             $perfdata = "\'io_usage\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "I/O usage=Not available";
          $state = check_state($state, $actual_state);
          }
       }
    
    if (($subselect eq "read") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][1]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O read=" . $value . " KB/s";
             $perfdata = $perfdata . " \'io_read\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O read=" . $value . " KB/s";
             $perfdata = " \'io_read\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O read=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O read=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "write") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][2]->value), 0);
          if ($subselect eq "all")
             {
             $output = $output . " - I/O write=" . $value . " KB/s";
             $perfdata = $perfdata . " \'io_write\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "I/O write=" . $value . " KB/s";
             $perfdata = " \'io_write\'=" . $value . "KB/s;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - I/O write=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "I/O write=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
       
    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown VM IO subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub vm_mem_info
    {
    my ($vmname) = @_;
    my $state = 0;
    my $output;
    my $value;
    my $perf_val_error = 1;      # Used as a flag when getting all the values 
                                 # with one call won't work.
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    $values = return_host_vmware_performance_values($vmname, 'mem', ('usage.average', 'consumed.average', 'overhead.average', 'active.average', 'vmmemctl.average'));
        
    if (defined($values))
       {
       $perf_val_error = 0;
       }
       
    if (defined($values))
       {
       $perf_val_error = 0;
       }
    else
       {
       $perf_val_error = 1;
       }
       
    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ($perf_thresholds ne ';')
          {
          print_help();
          print "\nERROR! Thresholds only allowed with subselects!\n\n";
          exit 2;
          }
       }

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname, 'mem', ('usage.average'));
          }

       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value) * 0.01);
          if ($subselect eq "all")
             {
             $output = "mem usage=" . $value . "%"; 
             $perfdata ="\'mem_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "mem usage=" . $value . "%"; 
             $perfdata ="\'mem_usage\'=" . $value . "%;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "mem usage=Not available"; 
          $state = check_state($state, $actual_state);
          }
       }
    
    if (($subselect eq "consumed") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname, 'mem', ('consumed.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][1]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - consumed memory=" . $value . " MB";
             $perfdata = $perfdata . " \'consumed_memory\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "consumed memory=" . $value . " MB";
             $perfdata = "\'consumed_memory\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - consumed memory=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "consumed memory=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "overhead") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname, 'mem', ('overhead.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][2]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - mem overhead=" . $value . " MB";
             $perfdata = $perfdata . " \'mem_overhead\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "mem overhead=" . $value . " MB";
             $perfdata = "\'mem_overhead\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - mem overhead=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "mem overhead=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }
    
    if (($subselect eq "active") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname, 'mem', ('active.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][3]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - mem active=" . $value . " MB";
             $perfdata = $perfdata . " \'mem_active\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "mem active=" . $value . " MB";
             $perfdata = "\'mem_active\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - mem active=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "mem active=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "memctl") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       if ($perf_val_error == 1)
          {
          $values = return_host_vmware_performance_values($vmname, 'mem', ('vmmemctl.average'));
          }

       if (defined($values))
          {
          if ($perf_val_error == 1)
             {
             $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
             }
          else
             {
             $value = simplify_number(convert_number($$values[0][4]->value) / 1024);
             }

          if ($subselect eq "all")
             {
             $output = $output . " - memctl=" . $value . " MB";
             $perfdata = $perfdata . " \'memctl\'=" . $value . "MB;" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "memctl=" . $value . " MB";
             $perfdata = "\'memctl\'=" . $value . "MB;" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " - memctl=Not available";
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "memctl=Not available";
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown VM MEM subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub vm_net_info
    {
    my ($vmname) = @_;
    my $state = 0;
    my $output;
    my $value;
    my $values;
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       if ( $perf_thresholds ne ";")
          {
          print "Error! Thresholds are only allowed with subselects!\n";
          }
       }

    $values = return_host_vmware_performance_values($vmname, 'net', ('usage.average:', 'received.average:*', 'transmitted.average:*'));

    if (($subselect eq "usage") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][0]->value));
          if ($subselect eq "all")
             {
             $output = "net usage=" . $value . " KBps"; 
             $perfdata = $perfdata . " \'net_usage\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net usage=" . $value . " KBps"; 
             $perfdata = "\'net_usage\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_state($state, $actual_state);
             }
          }
       else
          {
          $actual_state = 3;
          $output = "net usage=Not available"; 
          $state = check_state($state, $actual_state);
          }
       }

    if (($subselect eq "receive") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][1]->value));
          if ($subselect eq "all")
             {
             $output = $output . ", net receive=" . $value . " KBps"; 
             $perfdata = $perfdata . " \'net_receive\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net receive=" . $value . " KBps"; 
             $perfdata = "\'net_receive\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output = $output . " net receive=Not available"; 
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "net receive=Not available"; 
             $state = check_state($state, $actual_state);
             }
          }
       }

    if (($subselect eq "send") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (defined($values))
          {
          $value = simplify_number(convert_number($$values[0][2]->value));
          if ($subselect eq "all")
             {
             $output =$output . ", net send=" . $value . " KBps"; 
             $perfdata = $perfdata . " \'net_send\'=" . $value . ";" . $perf_thresholds . ";;";
             }
          else
             {
             $actual_state = check_against_threshold($value);
             $output = "net send=" . $value . " KBps"; 
             $perfdata = "\'net_send\'=" . $value . ";" . $perf_thresholds . ";;";
             $state = check_against_threshold($value);
             }
          }
       else
          {
          if ($subselect eq "all")
             {
             $actual_state = 3;
             $output =$output . ", net send=Not available"; 
             $state = check_state($state, $actual_state);
             }
          else
             {
             $actual_state = 3;
             $output = "net send=Not available"; 
             $state = check_state($state, $actual_state);
             }
          }
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown HOST-VM NET subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
sub vm_runtime_info
    {
    my ($vmname) = @_;
    my $state = 0;
    my $output = " ";
    my $runtime;                 # A reference to the runime view.
    my $vm_connectionState;      # Holds the vm connection state. It is shorter than
                                 # $runtime->connectionState->val in the code.
    my $vm_guestState;           # Holds the vm guest state. It is shorter than
                                 # $vm_view->guest->guestState in the code.
    my $tools_out;               # Temporary output in the tools section
    my $issues;                  # Hold a reference to the array of issues
    my $issue_cnt = 0;           # Counter for issues
    my $issue_out = '';          # Temporary output in the issue section
    my $actual_state;            # Hold the actual state for to be compared
    my $true_sub_sel=1;          # Just a flag. To have only one return at the en
                                 # we must ensure that we had a valid subselect. If
                                 # no subselect is given we select all
                                 # 0 -> existing subselect
                                 # 1 -> non existing subselect
    
    my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {name => $vmname}, properties => ['name', 'runtime', 'overallStatus', 'guest', 'configIssue']);

    if (!defined($vm_view))
       {
       print "VMware machine " . $vmname . " does not exist\n";
       exit 2;
       }

    $runtime = $vm_view->runtime;

    if (!defined($subselect))
       {
       # This means no given subselect. So all checks must be performemed
       # Therefore with all set no threshold check can be performed
       $subselect = "all";
       $true_sub_sel = 0;
       }


    if (($subselect eq "con") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $vm_connectionState = $runtime->connectionState->val;
       if ($vm_connectionState eq "connected")
          {
          $state = 0;
          $output = "Connection state: " . $vm_connectionState;
          }
       if (($vm_connectionState eq "disconnected") || ($vm_connectionState eq "orphaned"))
          {
          $state = 1;
          $output = "Connection state:" . $vm_connectionState;
          }
       if (($vm_connectionState eq "inaccessible") || ($vm_connectionState eq "invalid"))
          {
          $state = 1;
          $output = "Connection state:" . $vm_connectionState;
          }
       }


    if (($subselect eq "powerstate") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $actual_state = 0;
       if ($subselect eq "all")
          {
          $output = $output . " - Power state: " . $runtime->powerState->val;
          }
       else
          {
          $output = "Power state: " . $runtime->powerState->val;
          }
       $state = check_state($state, $actual_state);
       }


    if (($subselect eq "status") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $actual_state = check_health_state($vm_view->overallStatus->val);
       if ($subselect eq "all")
          {
          $output = $output . "  - Overall status: " . $vm_view->overallStatus->val;
          }
       else
          {
          $output = "Overall status: " . $vm_view->overallStatus->val;
          }
       $state = check_state($state, $actual_state);
       }


    if (($subselect eq "consoleconnections") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if ($subselect eq "all")
          {
          if ( $perf_thresholds ne ";")
             {
             $output = "Thresholds only allowed with valid subselect.";
             $actual_state = 2;
             }
          else
             {
             $actual_state = 0;
             $output = $output . " - Console connections: " . $runtime->numMksConnections;
             }
          }
       else
          {
          $actual_state = check_against_threshold($runtime->numMksConnections);
          $output = "Console connections:" . $runtime->numMksConnections;
          }
       $state = check_state($state, $actual_state);
       }


    if (($subselect eq "gueststate") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       if (exists($vm_view->guest->{toolsVersionStatus}) && defined($vm_view->guest->toolsVersionStatus) && exists($vm_view->guest->{toolsRunningStatus}) && defined($vm_view->guest->toolsRunningStatus))
          {
          if ($vm_view->guest->toolsVersionStatus ne "guestToolsNotInstalled")
             {
             if ($vm_view->guest->toolsRunningStatus ne "guestToolsNotRunning")
                {
                if ($vm_view->guest->toolsRunningStatus ne "guestToolsExecutingScripts")
                   {
                   $vm_guestState = $vm_view->guest->guestState;
            
                   if ($vm_guestState eq "running")
                      {
                      $actual_state = 0;
                      }
                   if (($vm_guestState eq "shuttingdown") || ($vm_guestState eq "resetting") || ($vm_guestState eq "standby") || ($vm_guestState eq "notrunning"))
                      {
                      $actual_state = 1;
                      }
                   if ($vm_guestState eq "unknown")
                      {
                      $actual_state = 3;
                      }
                   }
                else
                   {
                   $vm_guestState = "Not available. VMware tools starting.";
                   $actual_state = 1;
                   }
                }
             else
                {
                if (($runtime->powerState->val eq "poweredOff") || ($runtime->powerState->val eq "suspended"))
                   {
                   $vm_guestState = "Not available. VM powered off or suspended. VMware tools not running.";
                   $actual_state = 0;
                   }
                else
                   {
                   $vm_guestState = "Not available. VMware tools not running.";
                   $actual_state = 1;
                   }
                }
             }
          else
             {
             $vm_guestState = "Not available. VMware tools not installed.";
             $actual_state = 1;
             }
          }
       else
          {
          $vm_guestState = "Not available. No information about VMware tools available. Please check!";
          $actual_state = 1;
          }

       if ($subselect eq "all")
          {
          $output = $output . " - Guest state: " . $vm_guestState;
          }
       else
          {
          $output = "Guest state: " . $vm_guestState;
          }
       $state = check_state($state, $actual_state);
       }


    if (($subselect eq "tools") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;

       # VirtualMachineToolsRunningStatus
       # guestToolsExecutingScripts  VMware Tools is starting.
       # guestToolsNotRunning        VMware Tools is not running.
       # guestToolsRunning           VMware Tools is running. 
       
       # VirtualMachineToolsVersionStatus
       # guestToolsBlacklisted       VMware Tools is installed, but the installed version is known to have a grave bug and should be immediately upgraded.
       # Since vSphere API 5.0
       # guestToolsCurrent           VMware Tools is installed, and the version is current.
       # guestToolsNeedUpgrade       VMware Tools is installed, but the version is not current.
       # guestToolsNotInstalled      VMware Tools has never been installed.
       # guestToolsSupportedNew      VMware Tools is installed, supported, and newer than the version available on the host.
       # Since vSphere API 5.0
       # guestToolsSupportedOld      VMware Tools is installed, supported, but a newer version is available.
       # Since vSphere API 5.0
       # guestToolsTooNew            VMware Tools is installed, and the version is known to be too new to work correctly with this virtual machine.
       # Since vSphere API 5.0
       # guestToolsTooOld            VMware Tools is installed, but the version is too old.
       # Since vSphere API 5.0
       # guestToolsUnmanaged         VMware Tools is installed, but it is not managed by VMWare. 

       if (exists($vm_view->guest->{toolsVersionStatus}) && defined($vm_view->guest->toolsVersionStatus) && exists($vm_view->guest->{toolsRunningStatus}) && defined($vm_view->guest->toolsRunningStatus))
          {
          if ($vm_view->guest->toolsVersionStatus ne "guestToolsNotInstalled")
             {
             if ($vm_view->guest->toolsRunningStatus ne "guestToolsNotRunning")
                {
                if ($vm_view->guest->toolsRunningStatus ne "guestToolsExecutingScripts")
                   {
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsBlacklisted")
                      {
                      $tools_out = "VMware Tools are installed and running, but the installed ";
                      $tools_out = $tools_out ."version is known to have a grave bug and should ";
                      $tools_out = $tools_out ."be immediately upgraded.";
                      $actual_state = 2;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsCurrent")
                      {
                      $tools_out = "VMware Tools are installed, running and the version is current.";
                      $actual_state = 0;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsNeedUpgrade")
                      {
                      $tools_out = "VMware Tools are installed and running, but the version is not current.";
                      $actual_state = 1;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsSupportedNew")
                      {
                      $tools_out = "VMware Tools are installed, running, supported and newer than the ";
                      $tools_out = $tools_out ."version available on the host.";
                      $actual_state = 1;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsSupportedOld")
                      {
                      $tools_out = "VMware Tools are installed, running, supported, but a newer version is available.";
                      $actual_state = 1;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsTooNew")
                      {
                      $tools_out = "VMware Tools are installed and running but the version is known to be too new ";
                      $tools_out = $tools_out ."to work correctly with this virtual machine.";
                      $actual_state = 2;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsTooOld")
                      {
                      $tools_out = "VMware Tools are installed and running, but the version is too old.";
                      $actual_state = 1;
                      }
                   if ($vm_view->guest->toolsVersionStatus eq "guestToolsUnmanaged")
                      {
                      $tools_out = "VMware Tools are installed and running, but not managed by VMWare. ";
                      $actual_state = 2;
                      }
                   }
                else
                   {
                   $tools_out = "VMware tools starting.";
                   $actual_state = 1;
                   }
                }
             else
                {
                if (($runtime->powerState->val eq "poweredOff") || ($runtime->powerState->val eq "suspended"))
                   {
                   $tools_out = "VM powered off or suspended. VMware tools not running.";
                   $actual_state = 0;
                   }
                else
                   {
                   $tools_out = "VMware tools not running.";
                   $actual_state = 1;
                   }
                }
             }
          else
             {
             $tools_out = "VMware tools not installed.";
             $actual_state = 1;
             }
          }
       else
          {
          $tools_out = "No information about VMware tools available. Please check!";
          $actual_state = 1;
          }

       if ($subselect eq "all")
          {
          $output = $output . " - Tools state: " . $tools_out;
          }
       else
          {
          $output = "Tools state: " . $tools_out;
          }
       $state = check_state($state, $actual_state);
       }


    if (($subselect eq "issues") || ($subselect eq "all"))
       {
       $true_sub_sel = 0;
       $issues = $vm_view->configIssue;
       $actual_state = 0;

       if (defined($issues))
          {
          $issue_out = "Issues: ";
          foreach (@$issues)
                  {
                  $actual_state = 2;
                  $issue_cnt++;
                  $issue_out = $issue_out . $_->fullFormattedMessage . "(caused by " . $_->userName . ")" . $multiline;
                  }
          }

       if ($subselect eq "all")
          {
          $output = $output . " - " . $issue_cnt . " config issues";
          }
       else
          {
          $output = $issue_cnt . " config issues" . $multiline . $issue_out;
          }
       $state = check_state($state, $actual_state);
       }

    if ($true_sub_sel == 1)
       {
       get_me_out("Unknown VM RUNTIME subselect");
       }
    else
       {
       return ($state, $output);
       }
    }

# A module always must end with a returncode of 1. So placing 1 at the end of a module 
# is a common method to ensure this.
1;
#!/usr/bin/perl -w
#
# Nagios plugin to monitor vmware ESX and vSphere servers
#
# License: GPL
# This plugin is a forked by Martin Fuerstenau from the original one from op5
# Copyright (c) 2008 op5 AB
# Author: Kostyantyn Hushchyn <dev@op5.com>
# Contributor(s): Patrick Müller, Jeremy Martin, Eric Jonsson, stumpr, John Cavanaugh, Libor Klepac, maikmayers, Steffen Poulsen, Mark Elliott, simeg, sebastien.prudhomme, Raphael Schitz
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# History and Changes:
#
# - 22 Mar 2012 M.Fuerstenau
#   - Started with actual version 0.5.0
#   - Impelemented check_esx3new2.diff from Simon (simeg / simmerl)
#   - Reimplemented the changes of Markus Obstmayer for the actual version
#   - Comments within the code inform you about the changes
#   - It may happen that controllers has been found which are not active.
#     Therefor around line 2300        the following was added:
#
#     # M.Fuerstenau - additional to avoid using inactive controllers --------------
#      elsif (uc($dev->status) eq "3")
#            {
#            $status = 0;
#            }
#     #----------------------------------------------------------------------------
#           else
#            {
#            $state = 3;
#           }
#            $actual_state = Nagios::Plugin::Functions::max_state($actual_state, $status);
#            }
#            $perfdata = $perfdata . " adapters=" . $count . ";"$perf_thresholds . ";;";
#
#           # M.Fuerstenau - changed the output a little bit 
#           $output .= $count . " of " . @{$storage->storageDeviceInfo->hostBusAdapter} . " defined/possible adapters online, ";
#
# - 30 Mar 2012 M.Fuerstenau
#   - added --ignore_unknown. This maps 3 to 0. Why? You have for example several host adapters. Some are reported as
#     unknown by the plugin because they are not used or have not the capability to reports something senseful.
#
# - 02 Apr 2012 M.Fuerstenau
#   - _info (Adapter/LUN/Path). Removed perfdata. To count such items and display as perfdata doesn't make sense
#   - Changed PATH to MPATH and help from "path - list logical unit paths" to "mpath - list logical unit multipath info" because
#     it is NOT an information about a path - it is an information about multipathing.
#
# - 08 Jan 2013 M.Fuerstenau
#   - Removed installation informations for the perl SDK from VMware. This informations are part of the SDK and have nothing to do
#     with this plugin.
#   - Replaced global variables with my variables. Instead of "define every variable on the fly as needed it is a good practice
#     to define variables at the beginning and place a comment within it. It gives you better readability.
#
# - 22 Jan 2013 M.Fuerstenau
#   - Merged with the actual version from op5. Therfore all changes done to the op5 version:
#
#   - 2012-05-28  Kostyantyn Hushchyn
#     Rename check_esx3 to check_vmware_api(Fixed issue #3745)
#
#   - 2012-05-28  Kostyantyn Hushchyn
#     Minor cosmetic changes
#
#   - 2012-05-29  Kostyantyn Hushchyn
#     Clear cluster failover perfdata units, as it describes count of possible failures
#     to tolerate, so can't be mesured in MB
#
#   - 2012-05-30  Kostyantyn Hushchyn
#     Minor help message changes
#
#   - 2012-05-30  Kostyantyn Hushchyn
#     Implemented timeshift for cluster checks, which could fix data retrievel issues. Small refactoring.
#
#   - 2012-05-31  Kostyantyn Hushchyn
#     Remove dependency on inteval value for cluster checks, which allows to run commands that doesn't require historical intervals
#
#   - 2012-05-31  Kostyantyn Hushchyn
#     Remove unnecessary/unimplemented function which caused cluster effectivecpu subcheck to fail
#
#   - 2012-06-01  Kostyantyn Hushchyn
#     Hide NIC status output for net check in case of empty perf data result(Fixed issue #5450)
#
#   - 2012-06-07  Kostyantyn Hushchyn
#     Fixed manipulation with undefined values, which caused perl interpreter warnings output
#
#   - 2012-06-08  Kostyantyn Hushchyn
#     Moved out global variables from perfdata functions. Added '-M' max sample number argument, which specify maximum data count to retrive.
#
#   - 2012-06-08  Kostyantyn Hushchyn
#     Added help text for Cluster checks.
#
#   - 2012-06-08  Kostyantyn Hushchyn
#     Increment version number Kostyantyn Hushchyn
#
#   - 2012-06-11  Kostyantyn Hushchyn
#     Reimplemented csv parser to process all values in sequence. Now all required functionality for max sample number argument are present in the plugin.
#
#   - 2012-06-13  Kostyantyn Hushchyn
#     Fixed cluster failover perf counter output.
#
#   - 2012-06-22  Kostyantyn Hushchyn
#     Added help message for literal values in interval argument.
#
#   - 2012-06-22  Kostyantyn Hushchyn
#     Added nicknames for intervals(-i argument), which helps to provide correct values in case you can not find them in GUI.
#     Supported values are: r - realtime interval, h<number> - historical interval at position <number>, starting from 0.
#
#   - 2012-07-02  Kostyantyn Hushchyn
#     Reimplemented Datastore checking in Datacenter using different approach(Might fix issue #5712)
#
#   - 2012-07-06  Kostyantyn Hushchyn
#     Fixed Datacenter runtime check Kostyantyn Hushchyn
#
#   - 2012-07-06  Kostyantyn Hushchyn
#     Fixed Datastore checking in Datacenter(Might fix issue #5712)
#
#   - 2012-07-09  Kostyantyn Hushchyn
#     Added help info for Host runtime 'sensor' subcheck
#
#   - 2012-07-09  Kostyantyn Hushchyn
#     Added Host runtime subcheck to threshold sensor data
#
#   - 2012-07-09  Kostyantyn Hushchyn
#     Fixed Host temperature subcheck causing perl interpreter messages output
#
#   - 2012-07-10  Kostyantyn Hushchyn
#     Added listall option to output all available sensors. Sensor name now trieted as regexp, so result will be outputed for the first match.
#
#   - 2012-07-26  Fixed issue which prevents plugin...   v2.8.8 v2.8.8-beta1 Kostyantyn Hushchyn
#     Fixed issue which prevents plugin from executing under EPN(Fixed issue #5796)
#
#   - 2012-09-03  Kostyantyn Hushchyn
#     Implemented plugin timeout(returns 3).
#
#   - 2012-09-05  Kostyantyn Hushchyn
#     Added storage refresh functionality in case when it's present(Fixed issue #5787)
#
#   - 2012-09-21  Kostyantyn Hushchyn
#     Added check for dead pathes, which generates 2 in case when at least one is present(Fixed issue #5811)
#
#   - 2012-09-25  Kostyantyn Hushchyn
#     Changed comparison logic in storage path check
#
#   - 2012-09-26  Kostyantyn Hushchyn
#     Fixed 'Global symbol normalizedPathState requires explicit package name'
#
#   - 2012-10-02  Kostyantyn Hushchyn
#     Changed timeshift argument type to integer, so that non number values will be treated as invalid.
#
#   - 2012-10-02  Kostyantyn Hushchyn
#     Changed to a conditional datastore refresh(Reduce overhead of solution suggested in issue #5787)
#
#   - 2012-10-05  Kostyantyn Hushchyn
#     Updated description so now almost all options are documented, though somewhere should be documented arguments like timeshift(-T),
#     max samples(-M) and interval(-i) (Solve ticket #5950)
#
######################################################################################################################################
#
#   General statement for all changes done by me:
#
#   Nagios, Icingia etc. are tools for
#
#   a) Alarming. That means checking values against thresholds (internal or handed over)
#   b) Collecting performance data. These data, collected with the checks, like network traffic, cpu usage or so should be
#      interpretable without a lot of other data.
#
#   So as a conclusion collecting historic performance data collected by a monitored system should not be done using Nagios,
#   pnp4nagios etc.. It should be interpreted with the approriate admin tools of the relevant system. For vmware it means use
#   the (web)client for this and not Nagios. Same for performance counters not self explaining.
#
#   Example:
#   Monitoring swapped memory of a vmware guest system seems to makes sense. But on the second look it doesn't because on Nagios
#   you do not have the surrounding conditions in one view like
#   - the number of the running guest systems on the vmware server.
#   - the swap every guest system needs
#   - the total space allocated for all systems
#   - swap/memory usage of the hostcheck_vmware_esx.pl
#   - and a lot more
#
#   So monitoring memory of a host makes sense but the same for the guest via vmtools makes only a limited sense.
#   Martin Fuerstenau
#
######################################################################################################################################
#
# - 31 Jan 2013 M.Fuerstenau version 0.7.1
#   - Replaced most die with a normal if statement and an exit.
#
# - 1 Feb 2013 M.Fuerstenau version 0.7.2
#   - Replaced unless with if. unless was only used eight times in the program. In all other statements we had an if statement
#     with the appropriate negotiation for the statement.
#
# - 5 Feb 2013 M.Fuerstenau version 0.7.3
#   - Replaced all add_perfdata statements with simple concatenated variable $perfdata
#
# - 6 Feb 2013 M.Fuerstenau version 0.7.4
#   - Corrected bug. Name of subroutine was sub check_percantage but this was a typo.
#
# - 7 Feb 2013 M.Fuerstenau version 0.7.5
#   - Replaced $percc and $percw with $crit_is_percent and $warn_versionis_percent. This was just cosmetic for better readability.
#   - Removed check_percentage(). It was replaced by two one liners directly in the code. Easier to read.
#   - The only codeblocks using check_percentage() were the blocks checking warning and critical. But unfortunately the
#     plausability check was not sufficient. Now it is tested that no other values than numbers and the % sign can be
#     submitted. It is also checked that in case of percent the values are in a valid level between 0 and 100
#
# - 12 Feb 2013 M.Fuerstenau version 0.7.8
#   - Replaced literals like CRITICAL with numerical values. Easier to type and anyone developing plugins should be
#     safe with the use
#   - Replaced $state with $actual_state and $res with $state. More for cosmetical issues but the state is returned
#     to Nagios.
#   - check_against_threshold from Nagios::Plugin replaced with a little own subroutine check_against_threshold.
#   - Nagios::Plugin::Functions::max_state replaced with own routine check_state
#
# - 14 Feb 2013 M.Fuerstenau version 0.7.9
#   - Replaced hash %STATUS_TEXT from Nagios::Plugin::Functions with own hash %status2text.
#
# - 15 Feb 2013 M.Fuerstenau version 0.7.10
#   - Own help (print_help()) and usage (print_usage()) function.
#   - Nagios::plugin kicked finally out.
#   - Mo more global variables.
#
# - 25 Feb 2013 M.Fuerstenau version 0.7.11
#   - $quickstats instead of $quickStats for better readability.
#
# - 5 Mar 2013 M.Fuerstenau version 0.7.12
#   - Removed return_cluster_DRS_recommendations() because for daily use this was more of an exotical feature
#   - Removed --quickstats for host_cpu_info and dc_cpu_info because quickstats is not a valid option here.
#
# - 6 Mar 2013 M.Fuerstenau version 0.7.13
#   - Replaced -o listitems with --listitems
#
# - 8 Mar 2013 M.Fuerstenau version 0.7.14
#   - --usedspace replaces -o used. $usedflag has been replaced by $usedflag.
#   - --listvms replaces -o listvm. $outputlist has been replaced by $listvms.
#   - --alertonly replaces -o brief. $briefflag has been replaced by $alertonly.
#   - --blacklistregexp replaces -o blacklistregexp. $blackregexpflag has been replaced by $blacklistregexp.
#   - --isregexp replaces -o regexp. $regexpflag has been replaced by $isregexp.
#
# - 9 Mar 2013 M.Fuerstenau version 0.7.15
#   - Main selection is now transfered to a subroutine main_select because after
#     a successfull if statement the rest can be skipped leaving the subroutine
#     with return
#
# - 19 Mar 2013 M.Fuerstenau version 0.7.16
#   - Reformatted and cleaned up a lot of code. Variable definitions are now at the beginning of each 
#     subroutine instead of defining them "on the fly" as needed with "my". Especially using "my" for
#     definition in a loop is not goog coding style
#
# - 21 Mar 2013 M.Fuerstenau version 0.7.17
#   - --listvms removed as extra switch. Ballooning or swapping VMs will always be listed.
#   - Changed subselect list(vm) to listvm for better readability. listvm was accepted  before (equal to list)
#     but not mentioned in the help. To have list or listvm for the same is a little bit exotic. Fixed this inconsistency.
#
# - 22 Mar 2013 M.Fuerstenau version 0.7.18
#   - Removed timeshift, interval and maxsamples. If needed use original program from op5.
#
# - 25 Mar 2013 M.Fuerstenau version 0.7.19
#   - Removed $defperfargs because no values will be handled over. Only performance check that needed another 
#     another sampling invel was cluster. This is now fix with 3000.
#     
# - 11 Apr 2013 M.Fuerstenau version 0.7.20
#   - Rewritten and cleaned subroutine host_mem_info. Removed $value1 - $value5. Stepwise completion of $output makes
#     this unsophisticated construct obsolete.
#
# - 16 Apr 2013 M.Fuerstenau version 0.7.21
#   - Stripped down vm_cpu_info. Monitoring CPU usage in Mhz makes no sense under normal circumstances
#     Mhz is no valid unit for performance data according to the plugin developer guide. I have never found
#     a reason to monitor wait time or ready time in a normal alerting evironment. This data has some interest
#     for performance analysis. But this can be done better with the vmware tools.
#   - Rewritten and cleaned subroutine vm_mem_info. Removed $value1 - $value5. Stepwise completion of $output makes
#     this unsophisticated construct obsolete.
#
# - 24 Apr 2013 M.Fuerstenau version 0.7.22
#   - Because there is a lot of different performance counters for memory in vmware we ave changed something to be 
#     more specific.
#     - Enhenced explanations in help.
#     - Changed swap to swapUSED in host_mem_info().
#     - Changed usageMB to CONSUMED in host_mem_info(). Same for variables.
#     - Removed overall in host_mem_info(). After reading the documentation carefully the addition of consumed.average + overhead.average
#       seems a little bit senseless because consumed.average includes overhead.average.
#     - Changed usageMB to CONSUMED in vm_mem_info(). Same for variables.
#     - Removed swapIN and swapOUT in vm_mem_info(). Not so sensefull for Nagios alerting because it is hard to find 
#       valid thresholds
#     - Removed swap in vm_mem_info(). From the vmware documentation:
#       "Current amount of guest physical memory swapped out to the virtual machine's swap file by the VMkernel. Swapped 
#        memory stays on disk until the virtual machine needs it. This statistic refers to VMkernel swapping and not
#        to guest OS swapping. swapped = swapin + swapout"
#
#       This is more an issue of performance tuning rather than alerting. It is not swapping inside the virtual machine.
#       it is not possible to do any alerting here because (especially with vmotion) you have no thresholds.
#     - Removed OVERHEAD in vm_mem_info(). From the vmware documentation:
#       "Amount of machine memory used by the VMkernel to run the virtual machine."
#       So using this we have a useless information about a virtual machine because we have no valid context and we 
#       have no valid thresholds. More important is overhead for the host system. And if we are running in problems here
#       we have to look which machine must be moved to another host. 
#     - As a result of this overall in vm_mem_info() makes no sense.
#
# - 25 Apr 2013 M.Fuerstenau version 0.7.23
#   - Removed swap in vm_mem_info(). From vmware documentation:
#     "Amount of guest physical memory that is currently reclaimed from the virtual machine through ballooning.
#      This is the amount of guest physical memory that has been allocated and pinned by the balloon driver."
#     So here we have again data which makes no sense used alone. You need the context for interpreting them
#     and there are no thresholds for alerting.
#
# - 29 Apr 2013 M.Fuerstenau version 0.7.24
#   - Renamed $esx to $esx_server. This is only for cosmetics and better reading of the code.
#   - Reimplmented subselect ready in vm_cpu_info and implemented it new in host_cpu_info.
#     From the vmware documentation:
#     "Percentage of time that the virtual machine was ready, but could not get scheduled
#      to run on the physical CPU. CPU ready time is dependent on the number of virtual
#      machines on the host and their CPU loads."
#     High or growing ready time can be a hint CPU bottlenecks (host and guest system)
#   - Reimplmented subselect wait in vm_cpu_info and implemented it new in host_cpu_info.
#     From the vmware documentation:
#     "CPU time spent in wait state. The wait total includes time spent the CPU Idle, CPU Swap Wait,
#      and CPU I/O Wait states. "
#     High or growing wait time can be a hint I/O bottlenecks (host and guest system)
#
# - 30 Apr 2013 M.Fuerstenau version 0.7.25
#   - Removed subroutines return_dc_performance_values, dc_cpu_info, dc_mem_info, dc_net_info and dc_disk_io_info.
#     Monitored entity was view type HostSystem. This means, that the CPU of the data center server is monitored.
#     The data center server (vcenter) is either a physical MS Windows serversionver (which can be monitored better
#     directly with SNMP and/or NSClient++) or the new Linux based appliance which is a virtual machine and
#     can be monitored as any virtual machine. The OS (Linux) on that virtual machine can be monitored like
#     any standard Linux.
#
# - 5 May 2013 M.Fuerstenau version 0.7.26
#   - Revised the code of dc_list_vm_volumes_info()
#
# - 9 May 2013 M.Fuerstenau version 0.7.27
#   - Revised the code of host_net_info(). The function was devided in two parts (like others):
#     - subselects
#     - else which included all.
#     So most of the code existed twice. One for each subselect and nearly the same for all together.
#     The else block was removed and in case no subselect was defined we defined all as $subselect.
#     With the variable set to all we can decide wether to leave the function after a subselect section
#     has been processed or stay and enhance $output and $perfdata. So the code is more clear and
#     has nearly half the lines of code left.
#   - Removed KBps as unit in performance data. This unit is not specified in the plugin developer 
#     guide. Performance data is now just a number without a unit. Adding the unit has to be done 
#     in the graphing tool (like pnp4nagios).
#   - Removed the number of NICs as performance data. A little bit senseless to have those data here.
#
# - 10 May 2013 M.Fuerstenau version 0.7.27
#   - Revised the code of vm_net_info(). Same changes as for host_net_info() exept the NIC section.
#     This is not available for VMs.
#
# - 14 May 2013 M.Fuerstenau version 0.7.28
#   - Replaced $command and $subselect with $select and $subselect. Therfore also the options --command
#     --subselect changed to --select and --subselect. This has been done to become it more clear.
#     In fact these items where no commands (or subselects). It were selections from the amount of
#     performance counters available in vmware.
#
# - 15 May 2013 M.Fuerstenau version 0.7.29
#   - Kicked out all (I hope so) code for processing historic data from generic_performance_values().
#     generic_performance_values() is called by return_host_performance_values(), return_host_vmware_performance_values()
#     and return_cluster_performance_values() (return_cluster_performance_values() must be rewritten now).
#     The code length of generic_performance_values() was reduced to one third by doing this.
#
# - 6 Jun 2013 M.Fuerstenau version 0.7.30
#   - Substituted commandline option for select -l with -S. Therefore -S can't be used as option for the sessionfile
#     Only --sessionfile is accepted nor the name of the sessionfile.
#   - Corrected some bugs in check_against_threshold()
#   - Ensured that in case of thresholds critical must be greater than warning.
#
# - 11 Jun 2013 M.Fuerstenau version 0.7.31
#   - Changed select option for datastore from vmfs to volumes because we will have volumes on nfs AND vmfs on local or
#     SAN disks. 
#   - Changed output for datastore check to use the option --multiline. This will add a \n (unset -> default) for 
#     every line of output. If set it will use HTML tag <br>.
#
#     The option --multiline sets a <br> tag instead of \n. This must be filtered out
#     before using the output in notifications like an email. sed will do the job:
#
#     sed 's/<[Bb][Rr]>/&\n/g' | sed 's/<[^<>]*>//g'
#
#     Example:
#
#    # 'notify-by-email' command definition
#    define command{
#    	command_name	notify-by-email
#    	command_line	/usr/bin/printf "%b" "Message from Nagios:\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTNAME$\nHostalias: $HOSTALIAS$\nAddress: $HOSTADDRESS$\nState: $SERVICESTATE$\n\nDate/Time: $SHORTDATETIME$\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n$LONGSERVICEOUTPUT$" | sed 's/<[Bb][Rr]>/&\n/g' | sed 's/<[^<>]*>//g' | /bin/mail -s "** $NOTIFICATIONTYPE$ alert - $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$ **" $CONTACTEMAIL$
#    	}
#
# - 13 Jun 2013 M.Fuerstenau version 0.7.32
#   - Replaced a previous change because it was wrong done:
#     - --listvms replaced by subselect listvms
#
# - 14 Jun 2013 M.Fuerstenau version 0.7.33
#   - Some minor corrections like a doubled chop() in datastore_volumes_info()
#   - Added volume type to datastore_volumes_info(). So you can see whether the volume is vmfs (local or SAN) or NFS.
#   - variables like $subselect or $blacklist are global there is no need to handle them over to subroutines like
#     ($result, $output) = vm_cpu_info($vmname, local_uc($subselect)) . For $subselect we have now one uppercase
#     (around line 580) instead of having one with each call in the main selection.
#   - Later on I renamed local_uc to local_lc because I recognized that in cases the subselect is a volume name
#     upper cases won't work.
#   - replaced last -o $addopts (only for the name of a sensor) with --sensorname
#
# - 18 Jun 2013 M.Fuerstenau version 0.7.34
#   - Rewritten and cleaned subroutine host_disk_io_info(). Removed $value1 - $value7. Stepwise completion of $output makes
#     this unsophisticated construct obsolete.
#   - Removed use of performance thresholds in performance data when used disk io without subselect because threshold
#     can only be used for one item not for all. Therefore they weren't checked in that section. Senseless.
#   - Changed the output. Opposite to vm_disk_io_info() most values in host_disk_io_info() are not transfer rates
#     but latency in milliseconds. The output is now clearly understandable.
#   - Added subselect read. Average number of kilobytes read from the disk each second. Rate at which data is read
#     from each LUN on the host.read rate = # blocksRead per second x blockSize.
#   - Added subselect write. Average number of kilobytes written to disk each second. Rate at which data is written
#     to each LUN on the host.write rate = # blocksRead per second x blockSize
#   - Added subselect usage. Aggregated disk I/O rate. For hosts, this metric versionincludes the rates for all virtual
#     machines running on the host.
#
# - 21 Jun 2013 M.Fuerstenau version 0.7.35
#   - Rewritten and cleaned subroutine vm_disk_io_info(). Removed $value1 - $valuen. Stepwise completion of $output makes
#     this unsophisticated construct obsolete.
#   - Removed use of performance thresholds in performance data when used disk io without subselect because threshold
#     can only be used for on item not for all. Therefore they weren't checked in that section. Senseless.
#
# - 24 Jun 2013 M.Fuerstenau version 0.7.36
#   - Changed all .= (for example $output .= $xxx.....) to = $var... (for example $output = $output . $xxx...). .= is shorter
#     but the longer form of notification is better readable. The probability of overlooking the dot (especially for older eyes
#     like mine) is smaller. 
#
# - 07 Aug 2013 M.Fuerstenau version 0.8.0
#   - Changed "eval { require VMware::VIRuntime };" to "use VMware::VIRuntime;".  The eval construct 
#     made no sense. If the module isn't available the program will crash with a compile error.
#
#   - Removed own subroutine format_uptime() only used by host_uptime_info(). The complete work of this function
#     was done converting seconds to days, hours etc.. Instead of the we use the perl module Time::Duration.
#     So instead of
#        $output = "uptime=" . format_uptime($value);
#     we simply use
#        $output =  "uptime=" . duration_exact($value);
#
#   - Removed perfdata from host_uptime_info(). Perfdata for uptime seems senseless. Same for threshold.
#   - Started modularization of the plugin. The reason is that it is much more easier to 
#     patch modules than to patch a large file.
#   - Variables used in that functions which are defined on the top level
#     with "my" must now be defined with "our".
#
#     BEWARE! Using "our" with unknown modules can lead to curious results if
#     in this functions are variables with the same name. But in this 
#     case it is no risk because the modules are not generic. We have only
#     broken the plugin in handy pieces.
#
#   - Made an seperate modules:
#     - help.pm -> print_help()
#     - process_perfdata.pm  -> get_key_metrices()
#                            -> generic_performance_values()
#                            -> return_host_performance_values()
#                            -> return_host_vmware_performance_values()
#                            -> return_cluster_performance_values()
#                            -> return_host_temporary_vc_4_1_network_performance_values()
#     - host_cpu_info.pm -> host_cpu_info()
#     - host_mem_info.pm -> host_mem_info()
#     - host_net_info.pm -> host_net_info()
#     - host_disk_io_info.pm -> host_disk_io_info()
#     - datastore_volumes_info.pm -> datastore_volumes_info()
#     - host_list_vm_volumes_info.pm -> host_list_vm_volumes_info()
#     - host_runtime_info.pm -> host_runtime_info()
#     - host_service_info.pm -> host_service_info()
#     - host_storage_info.pm -> host_storage_info()
#     - host_uptime_info.pm -> host_uptime_info()
#
# - 13 Aug 2013 M.Fuerstenau version 0.8.1
#   - Moved host_device_info to host_mounted_media_info. Opposite to it's name
#     and the description this function wasn't designed to list all devices
#     on a host. It was designed to show host cds/dvds mounted to one or more
#     virtual machines. This is important for monitoring because a virtual machine
#     with a mount cd or dvd drive can not be moved to another host.
#   - Made an seperate modules:
#     - host_mounted_media_info.pm -> host_mounted_media_info()
#
# - 19 Aug 2013 M.Fuerstenau version 0.8.2
#   - Added SOAP check from Simon Meggle, Consol. Slightly modified to fit.
#   - Added isblacklisted and isnotwhitelisted from Simon Meggle, Consol. . Same as above.
#     Following subroutines or modules are affected:
#     - datastore_volumes_info.pm
#     - host_runtime_info.pm
#   - Enhanced host_mounted_media_info.pm
#     - Added check for host floppy
#     - Added isblacklisted and isnotwhitelisted
#     - Added $multiline
#
# - 21 Aug 2013 M.Fuerstenau version 0.8.3
#   - Reformatted and cleaned up host_runtime_info().
#   - A lot of bugs in it.
#
# - 17 Aug 2013 M.Fuerstenau version 0.8.4
#   - Minor bug fix.
#     - $subselect was always converted to lower case characters.
#       This is correct exect $subselect contains a name (e.g. volumes). Volume names
#       can contain upper and lower letters. Fixed.
#     - datastore_volumes_info.pm had  my ($datastore, $subselect) = @_; as second line
#       This was incorrect because "global" variables (defined as our in the main program)
#       are not handled over via function call. (Yes - may be handling over maybe more ok 
#       in the sense of structured programming. But really - does handling over and giving back 
#       a variable makes the code so much clearer? More a kind of philosophy :-)) )
#
# - 27 Oct 2013 M.Fuerstenau version 0.8.5
#   - Made an seperate modules:
#     - vm_cpu_info.pm -> vm_cpu_info()
#     - vm_mem_info.pm -> vm_mem_info()
#     - dc_list_vm_volumes_info.pm -> dc_list_vm_volumes_info()
#     - vm_net_info.pm -> vm_net_info()
#     - vm_disk_io_info.pm -> vm_disk_io_info()
#
# - 31 Oct 2013 M.Fuerstenau version 0.8.9
#   - Readded -V|--version to display the version number.
#
# - 01 Nov 2013 M.Fuerstenau version 0.8.10
#   - removed return_host_temporary_vc_4_1_network_performance_values() from
#     process_perfdata.pm. Not needed in ESX version 5 and above.
#     Affected subroutine:
#     host_net_info().
#   - Bug fixed in generic_performance_values(). Unfortunaltely I had moved
#     my @values = () to main function. Therefore instead of containing a 
#     new array reference with each run the new references were added to the array
#     but only the first one was processed. Thanks to Timo Weber for discovering this bug.
#
# - 20 Nov 2013 M.Fuerstenau version 0.8.11
#   - check_state(). Bugfix. Logical error. Complete rewrite.
#   - host_net_info()
#     - Minor bugfix. Added exit 2 in case of unallowed thresholds
#     - Simplified the output. Instead of doing it for every subselect (or not
#       if subselect=all for selecting all info) we have a new helper variable
#       called $true_sub_sel.
#       0 means not a true subselect.
#       1 means a true subselect (including all)
#   - host_runtime_info().
#     - Filtered out the sensor type "software components". Makes no sense for alerting.
#     - The complete else tree (no subselect) was scrap due to the fact that the return code
#       was always ok. There would never be any alarm. Kicked out.
#     - The else tree was replaced by a $subselect=all as in host_net_info().
#     - Same for output.
#     - subselect listvms.
#       - The (OK) in the output was a hardcoded. Replaced by the deliverd value (UP). (in my oipinion senseless)
#       - Removed perfdata. The number of virtual machines as perfdata doesn't
#         make so much sense.
#     - Rearranged the order of subselects. Must be the same as the statements
#       in the kicked out else sequence to get the same order in output
#     - connection state.
#
#       From the docs:
#       connected      Connected to the server. For ESX Server, this is always
#                      the setting.
#       disconnected   The user has explicitly taken the host down. VirtualCenter
#                      does not expect to receive heartbeats from the host. The
#                      next time a heartbeat is received, the host is moved to
#                      the connected state again and an event is logged.
#       notResponding  VirtualCenter is not receiving heartbeats from the server
#                    . The state automatically changes to connected once
#                      heartbeats are received again. This state is typically
#                      used to trigger an alarm on the host. 
#
#       In the past the presset of returncode was 2. It was set to 0 in case of a
#       connected. But disconnected doesn' mean a critical error. It means main-
#       tenance or somesting like that. Therefore we now return a 1 for warning.
#       notResonding will cause a 2 for critical.
#     - Kicked out maintenance info in runtime summary and as subselect. In the beginning of
#       the function is a check for maintenance. In the original program in this case
#       the program will be left with a die which caused a red alert in Nagios. Now an info 
#       is displayed and a return code of 1 (warning) is deliverd because a maintenance is
#       regular work. Although monitoring should take notice of it. Therefore a warning.
#       Therefor the maintenence check in the else tree was scrap. It was never reached.
#     - listvms
#       In case of no VMs the plugin returned a critical. But this is not correct. No VMs
#       on a host is not an error. It is simply what it says: No VMs.
#     - Replaced --listitems and --listall with --listsensors because there were two options
#       for the same use.
#     - Later on I decided to kick out the complete sensorname construction. To monitor a seperate sensor
#       by name (a string which ist different for each sensor) seems not to make so much sense. To monitor
#       sensors by type gave no usefull information (exept temperature which is still monitored. All usefull
#       informations are in the health section. Better to implement some out here if needed.
#       renamed -s temperature to -s temp (because I am lazy).
#     - Changed output of --listsensors. | is the seperation symbol for performance data. So it should not be
#       used in output strings.
#     - Same for the error output of sensors in case of a problem.
#     - subselect=health. Filter out sensors which have not valid data. Often a sensor is
#       reckognizedby vmware but has not the ability to report something senseful. In this
#       case an unknown is reported and the message "Cannot report on the current health state of
#       the element". This it can be skipped.
#   - Bugfix for vm_net_info(). It worked perfectly for -H but produced bullshit with the -D option.
#     With -D in PerfQuerySpec->new(...) intervalId and maxSample must be set. Default was 20 for intervalId
#     and 1 for maxSample
#   - datastore_volumes_info()
#     - New option --gigabyte
#     - Fixed bug for treating name as regexp (--isregexp).
#     - Fixed bug in perfdata (%:MB). Is now MB or GB.
#     - If no single volume is selected warning/critical threshold can be given
#       only in percent.
#   - Fixed bug in regexp for blacklists and whitelists and replace --blacklistregexp and --whitelistregexp with
#     --isregexp. Used in
#       - host_mounted_media_info()
#       - datastore_volumes_info()
#       - host_runtime_info()
#     All subroutines revised later will include it automatically
#   - Fixed bug in regexp for blacklists and whitelists and replace --blacklistregexp and --whitelistregexp with
#   - Opposite to the op5 original blacklists and whitelists can now contain true reular expressions.
#   - help.pm rewritten. It was too much output. Now the user has several choices:
#     -h|--help=<all>                    The complete help for all.
#     -h|--help=<dc|datacenter|vcenter>  Help for datacenter/vcenter checks.
#     -h|--help=<host>                   Help for vmware host checks.
#     -h|--help=<vm>                     Help for virtual machines checks.
#     -h|--help=<cluster>                Help for cluster checks.
#   - host_service_info() rewritten.
#     - No longer a list of services via subselect.
#     - Instead full blacklist/whitelist support
#     - With --isregexp blacklist/whitelist items are interpreted as regular expressions
#   - Changed switch of blacklist from -x to -B
#   - Changed switch of whitelist from -y to -W
#   - main_select(). Something for the scatterbrained of us. Replaced string compare (eq,ne etc.) with
#     a regexp pattern matching. So it is possible to type in services or Services instead of service.
#
# - 29 Nov 2013 M.Fuerstenau version 0.8.13
#   - In all functions checking host for maintenance we had the following contruction:
#
#     if (uc($host_view->get_property('runtime.inMaintenanceMode')) eq "TRUE")
#
#     This is quite stupid. runtime.inMaintenanceMode is xsd:boolean wich means true or false (in 
#     lower cas letters. So a uc() make no sense. Removed
#
#   - Bypass SSL certificate validation - thanks Robert Karliczek for the hint
#   - Added --sslport if any port other port than 443 is wanted. 443 is used as default.
#   - Rewritten authorization part. Sessionfiles are working now.
#   - Updated README.
#
# - 03 Dec 2013 M.Fuerstenau version 0.8.14
#   - host_runtime_info()
#     - Fixed minor bug. In case of an unknown with sensors the unknown was always mapped to
#       a warning. This wasn't sensefull under all circumstances. Now it is only mapped to warning
#       if --ignoreunknow is not set.
#   - README
#     - Updated installation notes
#   - Optional pathname for sessionfile
#
# - 10 Dec 2013 M.Fuerstenau version 0.8.15
#   - datastore_volumes_info()
#     - Changed "For all volumes" to "For all selected volumes". This should fit all. The subroutine datastore_volumes_info
#       is called from several subroutines and to make a difference here for a single volume or more volumes will cause
#       a lot of unnecessary work just for cosmetics.
#     - Fixed typo in error message.
#     - Modified error messages
#   - Removed plausibility check whether critical must be greater than warning. In case of freespace for example it must
#     be the other way round. The plausibility check was nice but too complicated for all the different conditions.
#   - check_against_threshold() - Cleaned up and partially rewritten.
#
# - 12 Dec 2013 M.Fuerstenau version 0.8.16
#   - datastore_volumes_info()
#     - Some small fixes
#       - Changed the output for OK from  "For all selected volumes" to "OK for all seleted volumes."
#       -  Same for error plus an error counter for the alarms
#     - Parameter usedspace was ignored on volume checks because a local variable defined with my instead of a more global
#       one. Changed it from my to our fixed it. Thanks to dgoetz for reporting (and fixing) this.
#     - Capacity is now displayed and deliverd as perfdata
#   - Main selection - GetOptions. Unce upon a time I had kicked out $timeout unintended. Fixed now. Thanks to 
#     Andreas Daubner for the hint.
#
# - 12 Dec 2013 M.Fuerstenau version 0.8.17
#   - host_net_info()
#     - Changed output
#     - Added total number of NICs
#
# - 13 Dec 2013 M.Fuerstenau version 0.8.18
#   - host_mounted_media()
#     - Delivers now a warning instead of a critical
#
# - 25 Dec 2013 M.Fuerstenau version 0.9.0
#   - help()
#     - Removed -v/--verbose. The code was not debugging the plugin but not for working with it.
#   - host_storage_info()
#     - Removed optional switch for adaptermodel. Displaying the adapter model is default now.
#     - Removed upper case conversion for status. The status was converted (for examplele online to ONLINE) and
#       compared with a upper case string like "ONLINE". Sensefull like a second asshole.
#     - Added working blacklist/whitelist.
#       - Blacklist: blacklisted adapters will not be displayed.
#       - Whitelist: only whitelisted adapters will be displayed.
#     - Removed perfdata for the number of hostbusadapters. These perfdata was absolutely senseless.     
#     - Status for hostbusadapters was not checked correctly. The check was only done for online and unknown but NOT(!!)
#       for offline and unbound.
#     - LUN states were not correct. UNKNOWN is not a valid state. Not all states different from unknown are 
#       supposed to be critical. From the docs:
#
#       degraded             One or more paths to the LUN are down, but I/O is still possible. Further
#                            path failures may result in lost connectivity.
#       error                The LUN is dead and/or not reachable.
#       lostCommunication    No more paths are available to the LUN.
#       off                  The LUN is off.
#       ok                   The LUN is on and available.
#       quiesced             The LUN is inactive.
#       timeout              All Paths have been down for the timeout condition determined by a
#                            user-configurable host advanced option.
#       unknownState         The LUN state is unknown.
#
#     - Removed number of LUNs as perfdata. Senseless (again).
#     - In the original selection for the displayed LUN the displayName was used first, then the deviceName and
#       the last one was the canonical name. Unfortunately in the GUI SCSI ID, canonical name an runtime name is
#       displayed. So using the freely configurable DisplayName is senseless. The device name is formed from the
#       path (/vmfs/devices/disks/) followed by the canonical name. So it is either senseless.
#     - The real numeric LUN number wasn'nt display. Fixed. Output is now LUN, canonical name, everything from
#       the display name not equal canonical name and status.  
#     - Complete rewrite of the paths part. Only the state of the multipath was checked but not the state of the
#       paths. So a multipath can be "Active" which is ok but the second line is dead. So if the active path becomes
#       dead the failover won't work.There must be an alarm for a standby path too. It is now grouped in the output.
#     - Multiline support for this.
#
# - 03 Jan 2014 M.Fuerstenau version 0.9.1
#   - check_vmware_esx.pl
#     Added new flag --ignore_warning. This will map a warning to ok.
#   - host_runtime_info() - some minor changes
#     - Changed state to powerstate. In the original version the power state was mapped:
#       poweredOn => UP
#       poweredOff => DOWN
#       suspended => SUSPENDED
#       This suggested a machine state but it is only a powerstate. All other than UP caused a critical. But this is 
#       not true. A power off machine can also be ok. But to be sure that it is noticed we will have a warning for
#       powerd off and suspended
#     - Perfdata changed.
#       - vm_up -> vm_powerdon
#       - New: vm_poweroff
#       - New: vm_suspended
#   - vm_runtime_info() -> vm_runtime_info.pm
#     - Removed a lot of unnecessary variables and hashes. Rewritten a lot.
#     - Connection state. Only "connected" was checked. All other caused a critical error without a usefull message.
#       This wa a little bit incomplete. Corrected. States delivered from VMware are connected, disconnected,
#       inaccessible, invalid and orphaned.
#     - Removed cpu. VirtualMachineRuntimeInfo maxCpuUsage (in Mhz) doesn't make so much sense for monitoring/alerting.
#       See VMware docs for further information for this performance counter.
#     - Removed mem. VirtualMachineRuntimeInfo maxMemoryUsage doesn't make so much sense for monitoring/alerting.
#       See VMware docs for further information for this performance counter.
#     - Changed state to powerstate. In the original version the power state was mapped:
#       poweredOn => UP
#       poweredOff => DOWN
#       suspended => SUSPENDED
#       This suggested a machine state but it is only a powerstate. All other than UP caused a critical. But this is 
#       not true. A power off machine can also be ok. But to be sure that it is noticed we will have a warning for
#       powerd off and suspended
#     - Changed guest to gueststate. This is more descriptive.
#       Removed mapping in guest state. Mapping was "running" => "Running", "notrunning" => "Not running",
#       "shuttingdown" => "Shutting down", "resetting" => "Resetting", "standby" => "Standby", "unknown" => "Unknown".
#       This was not necessary from a technical point of view. The original messages are clearly understandable.
#     - The guest states were not interpreted correctly. In check_vmware_api.pl all states different from running
#       caused a "Critical" error. But this is nonsense. A planned shutted down machine is not an error. It's daily
#       business. But the operator should probably have a notice of that. So it causing a "Warning".
#
#       The states are (from the docs):
#       running      -> Guest is running normally. (returns 0)
#       shuttingdown -> Guest has a pending shutdown command. (returns 1)
#       resetting    -> Guest has a pending reset command. (returns 1)
#       standby      -> Guest has a pending standby command. (returns 1)
#       notrunning   -> Guest is not running. (returns 1)
#       unknown      -> Guest information is not available. (returns 3)
#
#     - Rewritten subselect tools. VirtualMachineToolsStatus was deprecated. As of vSphere API 4.0
#       VirtualMachineToolsVersionStatus and VirtualMachineToolsRunningStatus
#       has to be used. So a great part of this subselect was not working.
#   - vm_disk_io_info()
#     - Minor bug in output and perfdata corrected. I/O is not in MB but in MB/s. Some
#       of the counters were in MB.
#     - Corrected help. The original on was nonsense.
#     - Changed all values to KB/s because so it is equal to host disk I/O and so it
#       it is deleverd from the API.
#   - help()
#     - Some small bug fixes.
#   - host_disk_io_info()
#     - added total_latency.
#
# - 08 Jan 2014 M.Fuerstenau version 0.9.2
#   - help()
#     - Some small bug fixes.
#   - vm_disk_io_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#   - host_disk_io_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#     - Bug fix. Usage was given without subselect but missing as subselect. Not
#       detected earlier due to the duplicate code.
#   - host_cpu_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#     - Added usage as subselect.
#   - vm_cpu_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#     - Added usage as subselect.
#   - host_mem_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#     - swapused
#       - I swapused is a subselect there should be enhanced information about
#         the virtual machines and should be available. If this won't work
#         nothing will happen. In the past this caused a critical error which
#         is nonsense here.
#      - memctl
#        - Same as swapused
#   - vm_mem_info()
#     - Removed duplicated code. (if subselect ..... else ....)
#       The code was 90% identical.
#     - Added vmmemctl.average (memctl) to monitor balloning.
#
# - 16 Jan 2014 M.Fuerstenau version 0.9.3
#   - All modules
#     - Corrected typo at the end. common instead of commen
#   - host_storage_info()
#     - Removed ignored counter for whitelisted items. A typical copy and paste
#       b...shit.
#   - vm_runtime_info()
#     - issues
#       - Some bugs with the output. Corrected.
#     - tools
#       - Minor bug fixed. Previously used variable was not removed.
#   - host_runtime_info()
#     - issues.
#       - Some bugs with the output. Corrected.
#     - listvms
#       - output now sorted by powerstate (suspended, poweredoff, powerdon)
#     - Corrected some minor bugs
#   - dc_list_vm_volumes_info()
#     - Removed handing over of unnecessary parameters
#   - dc_runtime_info() -> dc_runtime_info.pm
#     - Code cleaned up and reformated
#     - listvms
#       - output now sorted by powerstate (suspended, poweredoff, powerdon)
#       - Added working blacklist/whitelist with the ability to use regular
#         expressions
#       - Added --alertonly here
#       - Added --multiline here
#     - listhosts
#       - %host_state_strings was mostly nonsense. The mapped poser states from
#         for virtual machines were used. Hash removed. Using now the orginal 
#         power states from the system (from the docs):
#         - poweredOff -> The host was specifically powered off by the user
#                         through VirtualCenter. This state is not a certain
#                         state, because after VirtualCenter issues the command
#                         to power off the host, the host might crash, or kill
#                         all the processes but fail to power off.
#         - poweredOn  -> The host is powered on
#         - standBy    -> The host was specifically put in standby mode, either
#                         explicitly by the user, or automatically by DPM. This
#                         state is not a cetain state, because after VirtualCenter
#                         issues the command to put the host in stand-by state,
#                         the host might crash, or kill all the processes but fail
#                         to power off.
#         - unknown    -> If the host is disconnected, or notResponding, we can
#                         not possibly have knowledge of its power state. Hence,
#                         the host is marked as unknown. 
#       - Added working blacklist/whitelist with the ability to use regular
#         expressions
#       - Added --alertonly here
#       - Added --multiline here
#     - listcluster
#       - Removed senseless perf data
#       - More detailed check than before
#       - Added working blacklist/whitelist with the ability to use regular
#         expressions
#       - Added --alertonly here
#       - Added --multiline here
#     - status
#       - Rewritten and reformatted
#     - tools
#       - Rewritten and reformatted
#       - Improved more detailed output.
#         expressions
#       - Added --alertonly here
#       - Added --multiline here
#
# - 24 Jan 2014 M.Fuerstenau version 0.9.4
#   - Merged pull request from Sven Nierlein
#     - Modified hel to work with Thruk
#     - Added Makefile. This is optional. Calling it generates a single file
#       from all the modules. Maybe it is a little bit slower than the modules.
#       The readon for modules was speed and better maintenance.
#   - host_runtime_info()
#     - Added quotes in perfdata for temp.
#   - Enhanced README. Explained the differences un host_storage_info() between
#     the original one and this one
#   - host_net_info()
#     - Minor bugfix in output. Corrected typo.
#
# - 29 Jan 2014 M.Fuerstenau version 0.9.5
#   - host_runtime_info()
#     - Minor bug. Corrected quotes in perfdata for temp.
#   - vm_net_info()
#     - Quotes in perfdata
#     - Removed VM name from output
#   - vm_mem_info()
#     - Quotes in perfdata
#   - vm_disk_io_info()
#     - Quotes in perfdata
#   - vm_cpu_info()
#     - Quotes in perfdata
#   - host_net_info()
#     - Quotes in perfdata
#   - host_mem_info()
#     - Quotes in perfdata
#   - host_disk_io_info()
#     - Quotes in perfdata
#   - host_cpu_info()
#     - Quotes in perfdata
#   - dc_runtime_info()
#     - Quotes in perfdata
#   - datastore_volumes_info()
#     - Quotes in perfdata
#
# - 04 Feb 2014 M.Fuerstenau version 0.9.6
#   - host_storage_info()
#     - New switch --standbyok for storage systems where a standby multipath is ok
#       and not a warning
#
# - 06 Feb 2014 M.Fuerstenau version 0.9.7
#   - Bugfixes/Enhancements
#     - In some cases it might happen that no performance counters are delivered
#       by VMware. Especially if the version is old (4.x, 3.x). Under these
#       circumstances an undef was returned by the routines from process_perfdata.pm
#       and not handled correctly in the calling subroutines. Fixed.
#       Affected subroutines:
#       - host_cpu_info()
#       - vm_net_info()
#       - vm_mem_info()
#       - vm_net_info()
#       - vm_disk_io_info()
#       - vm_cpu_info()
#       - host_net_info()
#       - host_mem_info()
#       - host_disk_io_info()
#   - vm_net_info()
#     - Rewritten to the same structure as similar modules
#   - host_net_info()
#     - Rewritten to the same structure as similar modules
#
# - 24 Feb 2014 M.Fuerstenau version 0.9.8
#   - Corrected a type in the help()
#   - Moved the block for constructing the full path of the sessionfile downward to the authentication
#     stuff to have all in one place.
#   - Authentication:
#     - To reduce amounts of login/logout events in the vShpere logfiles or a lot of open sessions using
#       sessionfiles the login part has been rewritten. Using session files is now the default. Only one
#       session file per host or vCenter is used as default
#
#       The sessionfile name is automatically set to the vSphere host or the vCenter (IP or name - whatever
#       is used in the check).
#
#       Multiple sessions are possible using different session file names. To form different session file
#       names the default name is enhenced by the value you set with --sessionfile.
#
#       NOTICE! All checks using the same session are serialized. So a lot of checks using only one session
#       can cause timeouts. In this case you should enhence the number of sessions by using --sessionfile
#       in the command definition and define the value in the service definition command as an extra argument
#       so it can be used in the command definition as $ARGn$.
#     - --sessionfile is now optional and only used to enhance the sessionfile name to have multiple sessions.
#     - If a session logs in it sets a lock file (sessionfilename_locked).
#     - The lock file is been set when the session starts and removed at the end of the plugin run.
#     - A newly started check looks for the lock file and waits until it is no longer there. So here we
#       have a serialization now. It will not hang forever due to the alarm routine.
#     - Fixed bug "Can't call method "unset_logout_on_disconnect"". I mixed object orientated code and classical
#       code. (Thanks copy & paste for this bug)
#   - $timeout set to 40 seconds instead of 30 to have a little longer waiting before automatic cancelling
#     the check to prevent unwanted cancelling due to longer waiting caused by serialization.
#
# - 25 Feb 2014 M.Fuerstenau version 0.9.9
#   - Bugfix and improvement for "lost" lock files. In case of a Nagios reload (or kill -HUP) Nagios is restarted with the
#     same PID as before. Unfortunately Nagios sends a SIGINT or SIGTERM to the plugins. This causes the plugin
#     to terminate without removing the lockfile.
#     - So we have to catch several signals now
#       - SIGINT and SIGTERM. One of this will be send from Nagios 
#       - SIGALRM. Caused by alarm(). Now with output usable in Nagios.
#     - Instead of generating an empty file as lock file we write the process identifier of the running plugin
#       process into the lock file. If a session crashes for some reason an a lock file is left we are in a 
#       situation where signal processing won't help. But here the next run of the plugin reads the PID and checks
#       for the process. If there is no process anymore it will remove the lock file and create a new one.
#       Thanks to Simon Meggle, Consol, for the idea.
#   - Removed "die" for opening the authfile or the session lock file with an unless construct. The plugin will
#     report an "understandable" message to the monitor instead of causing an internal error code.
#   - vm_cpu_info() and host_cpu_info()
#     - Removed threshold for ready and wait. Therefore thresholds are no possible 
#       without subselect.
#
# - 26 Feb 2014 M.Fuerstenau version 0.9.10
#   - Bugfixes.
#     - Corrected typo in dc_runtime_info() line 660.
#     - Corrected typo in help().
#     - Corrected bug in datastore_volumes_info(). Giving absolute thresholds
#       for a single volume was not possible. Fixed.
#   - Removed print_usage(). Due to mass of parameters it is not possible to display
#     a short usage message. Instead of that the output of the help is included
#     in the package as a file.
#   - Updated default timeout to 90 secs. to avoid timeouts.
#   - Before accessing the session file (and lock file) we have a random sleep up
#     7 secs.. This is to avoid a concurrent access in case of a monitor restart
#     or a "Schedule a check of all services on this host"
#   - In case of a locked session file the wait loop is not fix to 1 sec any more.
#     Instead of this it uses a random period up to 5 sec.. So we minimize the risc
#     of concurrent access.
#
# - 7 Mar 2014 M.Fuerstenau version 0.9.11
#   - Updated README
#     - Section for removing HTML tags was reworked
#   - Added blacklist to host_net_info() so that interfaces with -S net can
#     be blacklisted.
#
# - 11 Mar 2014 M.Fuerstenau version 0.9.12
#   - Changed sleep() to usleep() and using now microseconds instead of seconds
#   - So before accessing the session file (and lock file) we now have a random sleep
#     up to 1500 milliseconds (default - see $ms_ts). This is to avoid a concurrent access
#     in case of a monitor restart or a "Schedule a check of all services on this host"
#     but takes much less time while having much more alternatives.
#   - In case of a locked session file the wait loop is not fix to a random period up to
#     5 sec. any more. Instead of this it uses also $ms_ts which means a max of 1.5 secs.
#     instead of 5.
#
# - 3 Apr 2014 M.Fuerstenau version 0.9.13
#   - --trace=<tracelevel> was not working. Fixed. Small typo.
#   - Removed comment sign in front of unlink around. It was there due to some
#     some tests and I had forgotten to remove it.
#   - datastore_volumes_info(). Some bugs corrected.
#     - Wrong percent calculation
#     - Wrong processing of thresholds for usedspace
#     - Wrong processing for thresholds which are not percent
#     - If threshold is in percent it is calculated in MB/GB for perfdata
#       because mixing percent and MB/GB doesn't make sense.
#
# - 5 Apr 2014 M.Fuerstenau version 0.9.14
#   - host_runtime_info()
#     - Fixed some bugs with issues ignored and whitelist. Some counters were calculated
#       wrong
#
# - 29 Apr 2014 M.Fuerstenau version 0.9.15
#   - host_mem_info(), vm_mem_info(), host_cpu_info() and vm_cpu_info().
#     - Sometimes it may happen on Vmware 5.5 (not seen when testing with Update 1) that getting
#       the perfdata for cpu and/or memory will result in an empty construct because one
#       or more values are not delivered. In this case we have a fallback and and every value
#   - dc_runtime_info()
#     - New option --poweredonly to list only machines which are powered on
#
# - 20 May 2014 M.Fuerstenau version 0.9.16
#   - New option --nosession.
#     - This was implemented for 2 reasons.
#       - First when testing from the commandline using this switch to avoid
#         waiting and timeouts while the monitor system is checking the the same host.
#         This is the important reason.
#       - Second is that some people don't like sessionfiles and prefer full logs as
#         it was in the past. Good ol' times.
#   - host_runtime_info()
#     - added --nostoragestatus to -S runtime -s health to avoid a double alarm
#       when also doing a check with -S runtime -s storagehealth for the same
#       host.
#   - dc_runtime_info()
#     - changed 
#       if (($subselect eq "listcluster") || ($subselect eq "all"))
#       to
#       if (($subselect =~ m/listcluster.*$/) || ($subselect eq "all"))
#       This is to avoid unnecessary typos because it covers listcluster and listclusters ;-)
#   - datastore_volumes_info()
#     -  Heavily reworked lot of the logical structure. There were too much changes
#        changes after changes which lead to bugs. Now it is cleaned up.
#   - cluster_list_vm_volumes_info()
#     - Seperate module now
#   - cluster_cpu_info()
#     - Seperate module now but still not working.
#
# - 1 Jul 2014 M.Fuerstenau version 0.9.16a
#   - Unfortunately published some modules containing debugging outpu. Fixed.
#     - host_disk_io_info.pm
#     - process_perfdata.pm
#     - vm_disk_io_info.pm
#
# - 20 Jul 2014 M.Fuerstenau version 0.9.17
#   - Removing the last multiline character (\n or <br>) was moved
#     from several subroutines to the main exit in check_vmware_esx.pl. 
#     This was based this was implemented based on a proposal of Dietmar Eberth
#     Affected subroutines:
#     - vm_runtime_info()
#     - host_storage_info()
#     - host_runtime_info()
#     - dc_runtime_info()
#     -datastore_volumes_info()
#   - Fixed a bug on line 139 and 172. Thanks for fixing it to Dietmar Eberth.
#     - Instead of 
#     
#       if ( $state >= 0 )
#          {
#          $alertcnt++;
#          }
#         
#       it must be:
#
#       if ( $alertcnt > 0 )
#          {
#          $alertcnt++;
#          }
#
#   - Fixed a bug on line 139 and 172. Thanks for fixing it to Dietmar Eberth.
#   - If only one volume is selected we have a better output now. Also thanks
#     to Dietmar Eberth.
#
# - 21 Jul 2014 M.Fuerstenau version 0.9.17a
#   - Bugfix line 139 and 172 (now 140 and 173). It must be 
#
#     if ( $actual_state > 0 )
#
#     instead of
#
#     if ( $alertcnt > 0
#
# - 25 Jul 2014 M.Fuerstenau version 0.9.18
#   - New option --perf_free_space for checking volumes. It must be used 
#     with --usedspace. In versions prior to 0.9.18 perfdata was always 
#     deliverd as free space even if --usedspace was selected. From 0.9.18
#     on when using --usedspace perfdata is recorded as used space. To prevent
#     old perfdata use this option.
#   - Cluster - removed checks for CPU and MEM
#     - Both checks were senseless for alarming because there are no thresholds.
#       A cluster or resource group is a group of Vmware hosts. Not a logical 
#       construct taking parts of the hosts in a resource group in a manner
#       that several clusters are using the same hosts. So the amount of CPU
#       and memory of all hosts is the CPU and memory of the cluster. Monitoring
#       this makes no sense because there are no thresholds for alerting. For
#       example 50% CPU usage of a cluster can be one host with 90%, and two
#       with 30% each. With an average of 50% everything seems to be ok but one
#       machine has definetely a problem. Same for memory. 
#
# - 21 Aug 2014 M.Fuerstenau version 0.9.19
#   - host_runtime_info()
#     - Some minor corrections in output.
#   - host_storage_info()
#     - Some corrections in output for LUNs. Using <code> in output was a
#       really stupid idea because the code (like ok,error-lostCommunication or
#       whatever is valid there) was interpreted as non existing HTML code.
#     - Some corrections in output for multipath/paths.
#     - Bugfix. Due to a wrong placed curly bracked the output was doubled. Fixed.
#   - host_runtime_info()
#     - Small bugfix. It may happen within the heath check that some values are not set
#       by VMware/hardware. In this case we have an
#       "[Use of uninitialized value in concatenation (.) or string ..."
#       To avoid this we check the values of the hash with each loop an in case a value
#       is not set we replace it whit the string "Unknown".
#
# - 24 Aug 2014 M.Fuerstenau version 0.9.20
#   - datastore_volumes_info(). Some improvements.
#     - Output. Because it was hard to see an alerting volume within the mass of others
#       the output is now grouped so that all alerting volumes are listed on top with 
#       a leading comment. Second are the volumes with no errors. Theses volumes are
#       seperated by a line and also introduced by a comment.
#     - New commandline switch --spaceleft.  When checking multiple volumes the threshold
#       must be given in either percent (old) OR space left on device.(New)
#
# - 28 Aug 2014 M.Fuerstenau version 0.9.20a
#   - datastore_volumes_info().
#     - Fixed some small bugs in output.
#
# - 7 Oct 2014 M.Fuerstenau version 0.9.21
#   - host_runtime_info()
#     - If the CIM server is not running (or not running correctly) the health
#       check receives a lot of unknown events even in the case the hardware
#       status from the GUI looks ok. So we check for the first CPU. If it is
#       unknown be sure the CIM server has to be restarted. After this you will
#       notice a difference in the GUI too.
#   - host_net_info()
#     - In case of an unplugged/disconnected NIC the state is now warning
#       instead of critical because an unplugged card is not always a critical
#       situtation but the admin should take notice of that.
#
# - 16 Dec 2014 M.Fuerstenau version 0.9.22
#   - Around line 1680:
#     - The previous check for an valid session was done with a string compare. This method
#       was taken from the VMware website. But it didn't work correctly. In $@ you will find
#       after an eval the error message in case of an error or nothing when it was successfull.
#       The problem was the string compare. If another language as English was choosen this
#       didn't work. So now it's only checked whether $@ has a content (error) or is empty (success).
#
# - 27 Dec 2015 M.Fuerstenau version 0.9.22a
#   - Bugfix:
#     - Instead of mapping 1 to 0 with --ignore_warning 2 was mapped to 0. Corrected.
#
# - 31 May 2015 M.Fuerstenau version 0.9.23
#   - check_vmware_esx.pl:
#     - New option --statelabel to have the label OK, CRITICAL etc. in plugin output to
#       fulfill the rules of the plugin developer guidelines. This was proposed by Simon Meggle.
#       See Readme.
#     - Added test for session file directory. Thanks Simon.
#     - Replaced variable $plugin_cache with $sessionfile_dir_def. $plugin_cache was copied from
#       another plugin of me. But this plugin doesn't  store any data. it was only used to store the 
#       session files (and session file lock files) and therefore the name was misleading.
#   - host_storage_info()
#     - Bugfix: Fixed bug in host storage adapter whitelisting.(Simon Meggle)
#     - Bugfix: Elements not matching the whitelist were not counted as ignored.(Simon Meggle)
#   - host_net_info()
#     - Bugfix: Fixed missing semicolon between some perf values and warning threshold.(Simon Meggle)
#   - host_runtime_info()
#     - Bugfix: Elements not matching the whitelist were not counted as ignored.(Simon Meggle)
#     - Raise a message after first host runtime issue. Changed state for that check to warning.(Simon Meggle)
#   - dc_runtime_info.pm
#     - Bugfix: Elements not matching the whitelist were not counted as ignored.(Simon Meggle)
#     - New option --showall. Without this only the tool status of machines with problems is listed.
#     -  Bugfix: "Installed,running,supported and newer than the version available on the host." was set
#        to warning but this is quit ok.
#      - In case of a complete runtime check the output is shorted. 
#   - vm_net_info()
#     - Bugfix: Fixed missing semicolon between some perf values and warning threshold.(Simon Meggle)
#
# - 31 May 2015 M.Fuerstenau version 0.9.24
#   - check_vmware_esx.pl:
#     - Option --statelabels changed from a switch to handing over a value (y or n). This was done as mentioned 
#       earlier to fulfill to have the label OK, CRITICAL etc. in plugin output to
#       fulfill the rules of the plugin developer guidelines. This was proposed by Simon Meggle.
#       See Readme.
#     - Bugfix: Wrong output for --statelabels from the help.
#
# - 3 Jun 2015 M.Fuerstenau version 0.9.25
#   - check_vmware_esx.pl:and dc_runtime_info()
#     - New optione --open-vm-tools to signalize that Open VM Tools are used and that the 
#       version of the tools on the host is obsolete.
#   - dc_runtime_info()
#     - "VMware Tools is installed, but it is not managed by VMWare" will except the previous point
#       now lead to a warning (1) instead of a critical (2).
#
#- 10 Jun 2015 M.Fuerstenau version 0.9.26
#  - help()
#    - Bugfix: --nosession was printed out twice. Same line the not "not" was missing.
#      This was bad because it changed the meaning of the line. Same error in the command reference
#      because the reference is only the output from the help in a file.

use strict;
use warnings;
use File::Basename;
use HTTP::Date;
use Getopt::Long;
use VMware::VIRuntime;
use Time::Duration;
use Time::HiRes qw(usleep);

# Own modules

#use lib "/usr/lib/nagios/vmware/modules";




# Prevent SSL certificate validation

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0; 

if ( $@ )
   {
   print "No VMware::VIRuntime found. Please download ";
   print "latest version of VMware-vSphere-SDK-for-Perl from VMware ";
   print "and install it.\n";
   exit 2;
   }

# Let's catch some signals
# Handle SIGALRM (timeout triggered by alarm() call)
$SIG{ALRM} = 'catch_alarm';
$SIG{INT}  = 'catch_intterm';
$SIG{TERM} = 'catch_intterm';
 

#--- Start presets and declarations -------------------------------------
# 1. Define variables

# General stuff
our $version;                                  # Only for showing the version
our $prog_version = '0.9.26';                  # Contains the program version number
our $ProgName = basename($0);

my  $PID = $$;                                 # Stores the process identifier of the actual run. This will be
                                               # be stored in the lock file. 
my  $PID_exists;                               # For testing for the process that wrote the lock file the last time
my  $PID_old;                                  # PID read from lock file

my  $help;                                     # If some help is wanted....
my  $NoA="";                                   # Number of arguments handled over
                                               # the program
# Login options
my  $username;                                 # Username for vmware host or vsphere server (datacenter)
my  $password;                                 # Password for vmware host or vsphere server (datacenter)
my  $authfile;                                 # If username/password should read from a file ....
my  $sessionfile_name;                         # Contains the name of the sessionfile if a
                                               # a sessionfile is used for faster authentication
my  $sessionlockfile;                          # Lockfile to protect the session
my  $sessionfile_dir;                          # Optinal. Contains the path to the sessionfile. Used in conjunction
                                               # with sessionfile
my  $nosession;                                # Just a flag to avoid using a sessionfile
my  $vim;                                       # Needed to stroe results ov Vim.

our $host;                                     # Name of the vmware server
my  $cluster;                                  # Name of the monitored cluster
our $datacenter;                               # Name of the vCenter server
our $vmname;                                   # Name of the virtual machine

my  $output;                                   # Contains the output string
my  $values;
my  $result;                                   # Contains the output string
our $perfdata;                                 # Contains the perfdata string.
my  $perfdata_init = "perfdata:";              # Contains the perfdata init string. We init $perfdata with
                                               # a stupid string because in case of concatenate perfdata
                                               # it is much more simple to remove a leading string with
                                               # a regular expression than to decide in every case wether
                                               # the variablecontains content or not.
$perfdata = $perfdata_init;                    # Init of perfdata. Using variables instead of literals ensures
                                               # that the string can be changed here without harm the function.
our $perf_thresholds = ";";                    # This contains the string with $warning, $critical or nothing
                                               # for $perfdata. If no thresold is set it is just ;

my  $url2connect;                              # Contains the URL to connect to the host
                                               # or the datacenter depending on the selected type
my  $sslport;                                  # If a port other than 443 is used.
my  $sslport_def = 443;                        # Default port
my  $select;
our $subselect;

our $warning;                                  # Warning threshold.
our $critical;                                 # Critical threshold.
our $reverse_threshold;                        # Flag. Needed if critical must be smaller than warning

our $crit_is_percent;                          # Flag. If it is set to one critical threshold is percent.
our $warn_is_percent;                          # Flag. If it is set to one warning threshold is percent.
my  $thresholds_given = 0;                     # During checking the threshold it will be set to one. Only if
                                               # it is set we will check the threshold against warning or critical
                                        
our $spaceleft;                                # This is used for datastore volumes. When checking multiple volumes
                                               # the threshol must be given in either percent or space left on device.
my  $sessionfile_dir_def="/tmp/";              # Directory for caching the session files and sessionfile lock files
                                               # Good idea to use a tmpfs because it speeds up operation    

our $listsensors;                              # This flag set in conjunction with -l runtime -s health or -s sensors
                                               # will list all sensors
our $usedspace;                                # Show used spaced instead of free
our $gigabyte;                                 # Output in gigabyte instead of megabyte
our $perf_free_space;                          # To display perfdata as free space instead of used when using
                                               # --usedspace
                                               
our $alertonly;                                # vmfs - list only alerting volumes

our $blacklist;                                # Contains the blacklist
our $whitelist;                                # Contains the whitelist

our $isregexp;                                 # treat names, blacklist and whitelists as regexp

my  $sec;                                      # Seconds      - used for some date functions
my  $min;                                      # Minutes      - used for some date functions
my  $hour;                                     # Hour         - used for some date functions
my  $mday;                                     # Day of month - used for some date functions
my  $mon;                                      # Month        - used for some date functions
my  $year;                                     # Year         - used for some date functions

my  $timeout = 90;                             # Time in seconds befor the plugin kills itself when it' not ready
my  $ms_ts = 1500;                             # Milliseconds to sleep for waiting for accessing the lockfile.

# Output options
our $multiline;                                # Multiline output in overview. This mean technically that
                                               # a multiline output uses a HTML <br> for the GUI instead of
                                               # Be aware that your messing connections (email, SMS...) must use
                                               # a filter to file out the <br>. A sed oneliner like the following
                                               # will do the job:
                                               # sed 's/<[^<>]*>//g'
my  $multiline_def="\n";                       # Default for $multiline;

our $vm_tools_poweredon_only;                  # Used with Vcenter runtime check to list only powered on VMs when
                                               # checking the tools
our $showall;                                  # Shows all where used
                                               # checking the tools
our $ignoreunknown;                            # Maps unknown to ok
our $ignorewarning;                            # Maps warning to ok
our $standbyok;                                # For multipathing if a standby multipath is ok
our $listall;                                  # used for host. Lists all available devices(use for listing purpose only)
our $nostoragestatus;                          # To avoid a double alarm when also doing a check with -S runtime -s health
                                               # and -S runtime -s storagehealth for the same host.

my $statelabels_def="y";                       # Default value for state labels in plugin output as described in the
                                               # Nagios Plugin Developer Guidelines. In my opinion this values don't make
                                               # sense but to to be compatible.... . It can be overwritten via commandline.
                                               # If you prefer no state labels (as it was default in earlier versions)
                                               # set this default to "n".
my $statelabels;                               # To overwrite $statelabels_def via commandline.
our $openvmtools;                              # Signalize that you use Open VM Tools instead of the servers one.



my  $trace;


# 2. Define arrays and hashes  

# The same as in Nagios::plugin::functions but it is ridiculous to buy a truck for a
# "one time one box" transportations job.

our %status2text = (
    0 => 'Ok',
    1 => 'Warning',
    2 => 'Critical',
    3 => 'Unknown',
    4 => 'Dependent',
);

#--- End presets --------------------------------------------------------

# First we have to fix  the number of arguments

$NoA=$#ARGV;

Getopt::Long::Configure('bundling');
GetOptions
	("h:s" => \$help,                "help:s"           => \$help,
	 "H=s" => \$host,                "host=s"           => \$host,
	 "C=s" => \$cluster,             "cluster=s"        => \$cluster,
	 "D=s" => \$datacenter,          "datacenter=s"     => \$datacenter,
	 "w=s" => \$warning,             "warning=s"        => \$warning,
	 "c=s" => \$critical,            "critical=s"       => \$critical,
	 "N=s" => \$vmname,              "name=s"           => \$vmname,
	 "u=s" => \$username,            "username=s"       => \$username,
	 "p=s" => \$password,            "password=s"       => \$password,
	 "f=s" => \$authfile,            "authfile=s"       => \$authfile,
	 "S=s" => \$select,              "select=s"         => \$select,
	 "s=s" => \$subselect,           "subselect=s"      => \$subselect,
	                                 "sessionfile=s"    => \$sessionfile_name,
	                                 "sessionfiledir=s" => \$sessionfile_dir,
	                                 "nosession"        => \$nosession,
	 "B=s" => \$blacklist,           "exclude=s"        => \$blacklist,
	 "W=s" => \$whitelist,           "include=s"        => \$whitelist,
         "t=s" => \$timeout,             "timeout=s"        => \$timeout,
	                                 "ignore_unknown"   => \$ignoreunknown,
	                                 "ignore_warning"   => \$ignorewarning,
	                                 "trace=s"          => \$trace,
                                         "listsensors"      => \$listsensors,
                                         "usedspace"        => \$usedspace,
                                         "perf_free_space"  => \$perf_free_space,
                                         "alertonly"        => \$alertonly,
                                         "multiline"        => \$multiline,
                                         "isregexp"         => \$isregexp,
                                         "listall"          => \$listall,
                                         "poweredonly"      => \$vm_tools_poweredon_only,
                                         "showall"          => \$showall,
                                         "standbyok"        => \$standbyok,
                                         "sslport=s"        => \$sslport,
                                         "gigabyte"         => \$gigabyte,
                                         "nostoragestatus"  => \$nostoragestatus,
                                         "statelabels"      => \$statelabels,
                                         "open-vm-tools"    => \$openvmtools,
                                         "spaceleft"        => \$spaceleft,
	 "V"   => \$version,             "version"          => \$version);

# Show version
if ($version)
   {
   print "Version $prog_version\n";
   print "This program is free software; you can redistribute it and/or modify\n";
   print "it under the terms of the GNU General Public License version 2 as\n";
   print "published by the Free Software Foundation.\n";
   exit 0;
   }

# Several checks to check parameters
if (defined($help))
   {
   print_help($help);
   exit 0;
   }

if (defined($blacklist) && defined($whitelist))
   {
   print "Error: -B|--exclude and -W|--include should not be used together.\n\n";
   print_help($help);
   exit 1;
   }

# Multiline output in GUI overview?
if ($multiline)
   {
   $multiline = "<br>";
   }
else
   {
   $multiline = $multiline_def;
   }

# Right number of arguments (therefore NoA :-)) )

if ( $NoA == -1 )
   {
   print_help($help);
   exit 1;
   }

# If you have set a timeout exit with alarm()
if ($timeout)
   {
   # Start the timer to script timeout
   alarm($timeout);
   }

$output = "Unknown ERROR!";
$result = 2;

# Check $subselect and if defined set it to upper case letters
if (defined($subselect))
   {
   if ($subselect eq '')
      {
      $subselect = undef;
      }
      else
      {
      if ( $select ne "volumes")
         {
         $subselect = local_lc($subselect)
         }
      }
   }

# Now we remove the percent sign if warning or critical is givenin percent
# Construct threshold part for perfomance data

if (defined($warning))
   {
   $warn_is_percent  = $warning =~ s/\%//;

   if ($warning eq '')
      {
      $warning = undef;
      $perf_thresholds = $perf_thresholds . ";";
      }
   else
      {
      # Numeric now or not?
      if ($warning =~ m/^[0-9]+$/)
         {
         $thresholds_given = 1;
         
         # If percent check a valid range
         if ($warn_is_percent eq 1)
            {
            if (!($warning > 0 && $warning <= 100 ))
               {
               print "Invalid warning threshold: $warning%\n\n";
               exit 2;
               }
            }
         $perf_thresholds = $warning .$perf_thresholds;
         }
      else
         {
         print "Warning threshold contains unwanted characters: $warning\n\n";
         exit 2;
         }
      }
   }

if (defined($critical))
   {
   $crit_is_percent  = $critical =~ s/\%//;

   if ($critical eq '')
      {
      $critical = undef;
      $perf_thresholds = $perf_thresholds . ";";
      }
   else
      {
      # Numeric now or not?
      if ($critical =~ m/^[0-9]+$/)
         {
         $thresholds_given = 1;

         # If percent check a valid range
         if ($crit_is_percent eq 1)
            {
            if (!($critical > 0 && $critical <= 100 ))
               {
               print "\nInvalid critical threshold: $critical%\n";
               exit 2;
               }
            }
         $perf_thresholds = $perf_thresholds . $critical;
         }
      else
         {
         print "Critical threshold contains unwanted characters: $critical\n\n";
         exit 2;
         }
      }
   }

# Check for authfile or valid username/password

if ((!defined($password) || !defined($username) || defined($authfile)) && (defined($password) || defined($username) || !defined($authfile)) && (defined($password) || defined($username) || defined($authfile) || !defined($sessionfile_name)))
   {
   print "Provide either Password/Username or Auth file or Session file\n";
   exit 2;
   }

# Check threshold unit

if (($warn_is_percent && !$crit_is_percent && defined($critical)) || (!$warn_is_percent && $crit_is_percent && defined($warning)))
   {
   print "Both threshold values must be the same units\n";
   exit 2;
   }

if (defined($authfile))
   {
   unless(open AUTH_FILE, '<', $authfile)
         {
         print "Unable to open auth file \"$authfile\"\n";
         exit 3;
         }
   
   while ( <AUTH_FILE> )
         {
         if (s/^[ \t]*username[ \t]*=//)
            {
            s/^\s+//;s/\s+$//;
            $username = $_;
            }
         if (s/^[ \t]*password[ \t]*=//)
            {
            s/^\s+//;s/\s+$//;
            $password = $_;
            }
         }
   if (!(defined($username) && defined($password)))
      {
      print "Auth file must contain both username and password\n";
      exit 2;
      }
   }

# Connection to a single host or a datacenter server?

if (defined($datacenter))
   {
   $url2connect = $datacenter;
   }
else
   {
   if (defined($host))
      {
      $url2connect = $host;
      }
   else
      {
      print "No Host or Datacenter specified\n";
      exit 2;
      }
   }

if (defined($sslport))
   {
   $url2connect = $url2connect . ":" . $sslport;
   }

$url2connect = "https://" . $url2connect . "/sdk/webService";

# Now let's do the login stuff

if (!defined($nosession))
   {
   if (defined($datacenter))
      {
      if (defined($sessionfile_name))
         {
         $sessionfile_name =~ s/ +//g;
         $sessionfile_name = $datacenter . "_" . $sessionfile_name . "_session";
         }
      else
         {
         $sessionfile_name = $datacenter . "_session";
         }
      }
   else
      {
      if (defined($sessionfile_name))
         {
         $sessionfile_name =~ s/ +//g;
         $sessionfile_name = $host . "_" . $sessionfile_name . "_session";
         }
      else
         {
         $sessionfile_name = $host . "_session";
         }
      }
      
   
   # Set default best location for sessionfile_dir_def in this environment
   if ( $ENV{OMD_ROOT}) 
      {
      $sessionfile_dir_def = $ENV{OMD_ROOT} . "/var/check_vmware_esx/";
      if ( ! -d $sessionfile_dir_def ) 
         {
         unless (mkdir $sessionfile_dir_def) 
            {
            die(sprintf "UNKNOWN: Unable to create sessionfile_dir_def directory %s.", $sessionfile_dir_def);
            }
         } 
      }

   if (defined($sessionfile_dir))
      {
      # If path contains trailing slash remove it
      $sessionfile_dir =~ s/\/$//;
      $sessionfile_name = $sessionfile_dir . "/" . $sessionfile_name;
      }
   else
      {
      $sessionfile_name = $sessionfile_dir_def . $sessionfile_name;
      }
   
   unless (-d $sessionfile_dir_def) 
          {
          die(sprintf "UNKNOWN: sessionfile_dir_def directory %s does not exist.", $sessionfile_dir_def);
          }

   $sessionlockfile = $sessionfile_name . "_locked";
   
   if ( -e $sessionfile_name )
      {
      usleep(int(rand($ms_ts)) * 1000);
      
      if ( -e $sessionlockfile )
         {
         # Session locked? First open the lock file for reading
         unless(open SESSION_LOCK_FILE, '<', $sessionlockfile)
               {
               print "Unable to open session lock file \"$sessionlockfile\"\n";
               exit 3;
               }
         # Second get the old PID
         while(<SESSION_LOCK_FILE>)
              {
              $PID_old = $_;
              }
         close (SESSION_LOCK_FILE);    
      
         # Third - check for the process which wrote the lock file the last time
         $PID_exists = kill 0, $PID_old;
         
         # Fourth - if the process is not available any more remove the lock file
         if ( !$PID_exists )
            {
            unlink $sessionlockfile;
            }
         }
   
      # Now we are sure that we have no dead lock file and we will wait for free session
      while ( -e $sessionlockfile )
            {
            usleep(int(rand($ms_ts)) * 1000);
            }
   
      unless(open SESSION_LOCK_FILE, '>', $sessionlockfile)
            {
            print "Unable to create session lock file \"$sessionlockfile\"\n";
            exit 3;
            }
      print SESSION_LOCK_FILE "$PID\n"; 
      close (SESSION_LOCK_FILE);    
   
      eval {Vim::load_session(session_file => $sessionfile_name)};
      if ($@ ne '')
         {
         unlink $sessionfile_name;
         Util::connect($url2connect, $username, $password);
         Vim::save_session(session_file => $sessionfile_name);
         }
      else
         {
         Vim::load_session(session_file => $sessionfile_name);
         }
      }
   else
      {
      unless(open SESSION_LOCK_FILE, '>', $sessionlockfile)
            {
            print "Unable to create session lock file \"$sessionlockfile\"\n";
            exit 3;
            }
      print SESSION_LOCK_FILE "$PID\n"; 
      close (SESSION_LOCK_FILE);    
   
      Util::connect($url2connect, $username, $password);
      Vim::save_session(session_file => $sessionfile_name);
      }
   }
else
   {
   Util::connect($url2connect, $username, $password);
   }

# Tracemode?
if (defined($trace))
   {
   $Util::tracelevel = $Util::tracelevel;

   if (($trace =~ m/^\d$/) && ($trace >= 0) && ($trace <= 4))
      {
      $Util::tracelevel = $trace;
      }
   }

$select = lc($select);

# This calls the main selection. It is now in a subroutine
# because after a successfull if statement the rest can be skipped
# leaving the subroutine with return

main_select();

if ($@)
   {
   if (uc(ref($@)) eq "HASH")
      {
      $output = $@->{msg};
      $result = $@->{code};
      }
   else
      {
      $output = $@ . "";
      $result = 2;
      }
   }

if (defined($sessionfile_name) and -e $sessionfile_name)
   {
   Vim::unset_logout_on_disconnect();
   unlink $sessionlockfile;
   }
else
   {
   Util::disconnect();
   }

# Added for mapping unknown to ok - M.Fuerstenau - 30 Mar 2011

if (defined($ignoreunknown))
   {
   if ($result eq 3)
      {
      $result = 0;
      }
   }
# Added for mapping warning to ok - M.Fuerstenau - 31 Dec 2013

if (defined($ignorewarning))
   {
   if ($result eq 1)
      {
      $result = 0;
      }
   }

# Now we remove the leading init string and whitespaces from the perfdata
$perfdata =~ s/^$perfdata_init//;
$perfdata =~ s/^[ \t]*//;

# $statelabels set or using default?
if (defined($statelabels))
   {
   # This eliminates typos like Y or yes or nO etc.
   if ($statelabels =~ m/^y.*$/i)
      {
      $statelabels = "y";
      }
   else
      {
      if ($statelabels =~ m/^n.*$/i)
         {
         $statelabels = "n";
         }
      else
         {
         print "Wrong value for --statelabels. Must be y or no and not $statelabels\n";
         exit 2;
         }
      }
   }
else
   {
   $statelabels = $statelabels_def;
   }
   
   
if ( $result == 0 )
   {
   if ($statelabels eq "y")
      {
      print "OK: $output";
      }
   else
      {
      print "$output";
      }

   if ($perfdata)
      {
      print "|$perfdata\n";
      }
      else
      {
      print "\n";
      }
   }

# Remove the last multiline regardless whether it is \n or <br>
$output =~ s/$multiline$//;

if ( $result == 1 )
   {
   if ($statelabels eq "y")
      {
      print "WARNING: $output";
      }
   else
      {
      print "$output";
      }

   if ($perfdata)
      {
      print "|$perfdata\n";
      }
   else
      {
      print "\n";
      }
   }

if ( $result == 2 )
   {
   if ($statelabels eq "y")
      {
      print "CRITICAL: $output";
      }
   else
      {
      print "$output";
      }

   if ($perfdata)
      {
      print "|$perfdata\n";
      }
   else
      {
      print "\n";
      }
   }

if ( $result == 3 )
   {
   if ($statelabels eq "y")
      {
      print "UNKNOWN: $output";
      }
   else
      {
      print "$output";
      }

   if ($perfdata)
      {
      print "|$perfdata\n";
      }
   else
      {
      print "\n";
      }
   }

exit $result;

#######################################################################################################################################################################

sub main_select
    {
    if (defined($vmname))
       {
       if ($select eq "cpu")
          {


          ($result, $output) = vm_cpu_info($vmname);
          return($result, $output);
          }
       if ($select eq "mem")
          {


          ($result, $output) = vm_mem_info($vmname);
          return($result, $output);
          }
       if ($select eq "net")
          {


          ($result, $output) = vm_net_info($vmname);
          return($result, $output);
          }
       if ($select eq "io")
          {


          ($result, $output) = vm_disk_io_info($vmname);
          return($result, $output);
          }
       if ($select eq "runtime")
          {


          ($result, $output) = vm_runtime_info($vmname);
          return($result, $output);
          }
       if ($select eq "soap")
          {
          ($result, $output) = soap_check();
          return($result, $output);
          }

          get_me_out("Unknown host-vm select");
        }

    if (defined($host))
       {
       # The following if black is only needed if we check a ESX server via the 
       # the datacenten (vsphere server) instead of doing it directly.
       # Directly is better
       
       my $esx_server;
       if (defined($datacenter))
          {
          $esx_server = {name => $host};
          }
       if ($select eq "cpu")
          {


          ($result, $output) = host_cpu_info($esx_server);
          return($result, $output);
          }
       if ($select eq "mem")
          {


          ($result, $output) = host_mem_info($esx_server);
          return($result, $output);
          }
       if ($select eq "net")
          {


          ($result, $output) = host_net_info($esx_server);
          return($result, $output);
          }
       if ($select eq "io")
          {


          ($result, $output) = host_disk_io_info($esx_server);
          return($result, $output);
          }
       if ($select eq "volumes")
          {


          ($result, $output) = host_list_vm_volumes_info($esx_server);
          return($result, $output);
          }
       if ($select eq "runtime")
          {


          ($result, $output) = host_runtime_info($esx_server);
          return($result, $output);
          }
       # service OR services because I always type the wrong one :-)) - M.Fuerstenau
       if ($select =~ m/^service.?$/)
          {


          ($result, $output) = host_service_info($esx_server);
          return($result, $output);
          }
       if ($select eq "storage")
          {


          ($result, $output) = host_storage_info($esx_server, $blacklist);
          return($result, $output);
          }
       if ($select eq "uptime")
          {


          ($result, $output) = host_uptime_info($esx_server);
          return($result, $output);
          }
       if ($select eq "hostmedia")
          {


          ($result, $output) = host_mounted_media_info($esx_server);
          return($result, $output);
          }
       if ($select eq "soap")
          {
          ($result, $output) = soap_check();
          return($result, $output);
          }

          get_me_out("Unknown host select");
        }

    if (defined($cluster))
       {
       if ($select eq "cluster")
          {
          ($result, $output) = cluster_cluster_info($cluster);
          return($result, $output);
          }
       if ($select eq "volumes")
          {


          ($result, $output) = cluster_list_vm_volumes_info($cluster);
          return($result, $output);
          }
       if ($select eq "runtime")
          {
          ($result, $output) = cluster_runtime_info($cluster, $blacklist);
          return($result, $output);
          }
       if ($select eq "soap")
          {
          ($result, $output) = soap_check();
          return($result, $output);
          }

          get_me_out("Unknown cluster select");
        }

    if (defined($datacenter))
       {
       if ($select eq "volumes")
          {


          ($result, $output) = dc_list_vm_volumes_info();
          return($result, $output);
          }
       if ($select eq "runtime")
          {


          ($result, $output) = dc_runtime_info();
          return($result, $output);
          }
       if ($select eq "soap")
          {
          ($result, $output) = soap_check();
          return($result, $output);
          }

       get_me_out("Unknown datacenter select");
       }
    get_me_out("You should never end here. Totally unknown anything.");
    }
    
sub check_against_threshold
    {
    my $check_result = shift(@_);
    my $return_state = 0;
 

    if ((defined($warning)) && (defined($critical)))
       {
       if ( $warning >= $critical )
          {
          if ( $check_result <= $warning)
             {
             $return_state = 1;
             }
          if ( $check_result <= $critical)
             {
             $return_state = 2;
             }
          }
       else
          {
          if ( $check_result >= $warning)
             {
             $return_state = 1;
             }
          if ( $check_result >= $critical)
             {
             $return_state = 2;
             }
          }
       }
    else
       {
       if (defined($warning))
          {
          if ( $check_result >= $warning)
             {
             $return_state = 1;
             }
          }

       if (defined($critical))
          {
          if ( $check_result >= $critical)
             {
             $return_state = 2;
             }
          }
       }
    return $return_state;
    }
    
sub check_state
    {
    if (grep { $_ == 2 } @_)
       {
       return 2;
       }
    if (grep { $_ == 1 } @_)
       {
       return 1;
       }
    if (grep { $_ == 3 } @_)
       {
       return 3;
       }
    if (grep { $_ == 0 } @_)
       {
       return 0;
       }
    return 3;
    }

sub local_lc
    {
    my ($val) = shift(@_);
    if (defined($val))
       {
       return lc($val);
       }
    else
       {
       return undef;
       }
    }

sub simplify_number
    {
    my ($number, $cnt) = @_;
    if (!defined($cnt))
       {
       $cnt = 2;
       }
    return sprintf("%.${cnt}f", "$number");
    }

sub convert_number
    {
    my @vals = split(/,/, shift(@_));
    my $state = 0;
    my $value;

    while (@vals)
          {
          $value = pop(@vals);
          $value =~ s/^\s+//;
          $value =~ s/\s+$//;
          
          if (defined($value) && $value ne '')
             {
             if ($value >= 0)
                {
                return $value;
                }
             if ($state == 0)
                {
                $state = $value;
                }
             }
          }
    return $state;
    }

sub check_health_state
    {
    my ($actual_state) = shift(@_);
    my $state = 3;

    if (lc($actual_state) eq "green")
       {
       $state = 0
       }

    if (lc($actual_state) eq "yellow")
       {
       $state = 1;
       }
 
    if (lc($actual_state) eq "red")
       {
       $state = 2;
       }
    return $state;
    }

sub format_issue
    {
    my ($issue) = shift(@_);
    my $output = '';

    if (defined($issue->datacenter))
       {
       $output = $output . 'Datacenter "' . $issue->datacenter->name . '", ';
       }

    if (defined($issue->host))
       {
       $output = $output . 'Host "' . $issue->host->name . '", ';
       }

    if (defined($issue->vm))
       {
       $output = $output . 'VM "' . $issue->vm->name . '", ';
       }

    if (defined($issue->computeResource))
       {
       $output = $output . 'Compute Resource "' . $issue->computeResource->name . '", ';
       }

    if (exists($issue->{dvs}) && defined($issue->dvs))
       {
       # Since vSphere API 4.0
       $output = $output . 'Virtual Switch "' . $issue->dvs->name . '", ';
       }

    if (exists($issue->{ds}) && defined($issue->ds))
       {
       # Since vSphere API 4.0
       $output = $output . 'Datastore "' . $issue->ds->name . '", ';
       }

    if (exists($issue->{net}) && defined($issue->net))
       {
       # Since vSphere API 4.0
       $output = $output . 'Network "' . $issue->net->name . '" ';
       }

       $output =~ s/, $/ /;
       $output = $output . ": " . $issue->fullFormattedMessage;
       if ($issue->userName ne "")
          {
          $output = $output . "(caused by " . $issue->userName . ")";
          }

       return $output;
}

# SOAP check, isblacklisted and isnotwhitelisted from Simon Meggle, Consol.
#  Slightly modified to for this plugin by M.Fuerstenau. Oce Printing Systems

sub soap_check
    {
    my $output = 'Fatal error: could not connect to the VMWare SOAP API.';
    my $state = Vim::get_vim_service();
    
    if (defined($state))
       {
       $state=0;
       $output = 'Successfully connected to the VMWare SOAP API.';
       }
    else
       {
       $state=2;
       }
    return ($state, $output);
    }

sub isblacklisted
    {
    my ($blacklist_ref,$regexpflag,$candidate) = @_;
    my $ret = 0;
    my @blacklist;
    my $blacklist;
    my $hitcount = 0;
    
    if (!defined $$blacklist_ref)
       {
       return 0;
       }

    if ($regexpflag == 0)
       {
       $ret = grep(/$candidate/, $$blacklist_ref);
       }
    else
       {
       @blacklist = split(/,/, $$blacklist_ref);

       foreach $blacklist (@blacklist)
               {
               if ($candidate =~ m/$blacklist/)
                  {
                  $hitcount++;
                  }
               }

       if ($hitcount >= 1)
          {
          $ret = 1;
          }
       }
    return $ret;
}

sub isnotwhitelisted
    {
    my ($whitelist_ref,$regexpflag,$candidate) = @_;
    my $ret = 0;
    my @whitelist;
    my $whitelist;
    my $hitcount = 0;

    if (!defined $$whitelist_ref)
       {
       return $ret;
       }

    if ($regexpflag == 0)
       {
       $ret = ! grep(/$candidate/, $$whitelist_ref);
       }
    else
       {
       @whitelist = split(/,/, $$whitelist_ref);

       foreach $whitelist (@whitelist)
               {
               if ($candidate =~ m/$whitelist/)
                  {
                  $hitcount++;
                  }
               }

       if ($hitcount == 0)
          {
          $ret = 1;
          }
       }
    return $ret;
    }

# The "ejection seat". Display error message and leaves the program.
sub get_me_out
    {
    my ($msg) = @_;
    print "$msg\n";
    print "\n";
    print_help();
    exit 2;
    }
    
# Catching some signals
sub catch_alarm
    {
    print "UNKNOWN: Script timed out.\n";
    exit 3;
    }

sub catch_intterm
    {
    print "UNKNOWN: Script killed by monitor.\n";
    unlink $sessionlockfile;
    exit 3;
    }
 
#=====================================================================| Cluster |============================================================================#

sub cluster_cluster_info
{
        my ($cluster) = @_;
         
        my $state = 2;
        my $output = 'CLUSTER clusterServices Unknown error';
        
        if (defined($subselect))
        {
                if ($subselect eq "effectivecpu")
                {
                        $values = return_cluster_performance_values($cluster, 'clusterServices', ('effectivecpu.average'));
                        if (defined($values))
                        {
                                my $value = simplify_number(convert_number($$values[0][0]->value) * 0.01);
                                $perfdata = $perfdata . " effective cpu=" . $value . "Mhz;" . $perf_thresholds . ";;";
                                $output = "effective cpu=" . $value . "%"; 
                                $state = check_against_threshold($value);
                        }
                }
                elsif ($subselect eq "effectivemem")
                {
                        $values = return_cluster_performance_values($cluster, 'clusterServices', ('effectivemem.average'));
                        if (defined($values))
                        {
                                my $value = simplify_number(convert_number($$values[0][0]->value) / 1024);
                                $perfdata = $perfdata . " effectivemem=" . $value . "MB;" . $perf_thresholds . ";;";
                                $output = "effective mem=" . $value . " MB";
                                $state = check_against_threshold($value);
                        }
                }
                elsif ($subselect eq "failover")
                {
                        $values = return_cluster_performance_values($cluster, 'clusterServices', ('failover.latest:*'));
                        if (defined($values))
                        {
                                my $value = simplify_number(convert_number($$values[0][0]->value));
                                $perfdata = $perfdata . " failover=" . $value . ";" . $perf_thresholds . ";;";
                                $output = "failover=" . $value . " ";
                                $state = check_against_threshold($value);
                        }
                }
                elsif ($subselect eq "cpufairness")
                {
                        $values = return_cluster_performance_values($cluster, 'clusterServices', ('cpufairness.latest'));
                        if (defined($values))
                        {
                                my $value = simplify_number(convert_number($$values[0][0]->value));
                                $perfdata = $perfdata . " cpufairness=" . $value . "%;" . $perf_thresholds . ";;";
                                $output = "cpufairness=" . $value . "%";
                                $state = check_against_threshold($value);
                        }
                }
                elsif ($subselect eq "memfairness")
                {
                        $values = return_cluster_performance_values($cluster, 'clusterServices', ('memfairness.latest'));
                        if (defined($values))
                        {
                                my $value = simplify_number((convert_number($$values[0][0]->value)));
                                $perfdata = $perfdata . " memfairness=" .  $value . "%;" . $perf_thresholds . ";;";
                                $output = "memfairness=" . $value . "%";
                                $state = check_against_threshold($value);
                        }
                }
                else
                {
                get_me_out("Unknown CLUSTER clusterservices subselect");
                }
        }
        else
        {
                $values = return_cluster_performance_values($cluster, 'clusterServices', ('effectivecpu.average', 'effectivemem.average'));
                if (defined($values))
                {
                        my $value1 = simplify_number(convert_number($$values[0][0]->value));
                        my $value2 = simplify_number(convert_number($$values[0][1]->value) / 1024);
                        $perfdata = $perfdata . " effective cpu=" . $value1 . "Mhz;" . $perf_thresholds . ";;";
                        $perfdata = $perfdata . " effective mem=" . $value2 . "MB;" . $perf_thresholds . ";;";
                        $state = 0;
                        $output = "effective cpu=" . $value1 . " Mhz, effective Mem=" . $value2 . " MB";
                }
        }

        return ($state, $output);
}


sub cluster_runtime_info
{
        my ($cluster, $blacklist) = @_;

        my $state = 2;
        my $output = 'CLUSTER RUNTIME Unknown error';
        my $runtime;
        my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => "$cluster" }, properties => ['name', 'overallStatus', 'configIssue']);

        if (!defined($cluster_view))
           {
           print "Cluster " . $$cluster{"name"} . " does not exist.\n";
           exit 2;
           }

        $cluster_view->update_view_data();

        if (defined($subselect))
        {
                if ($subselect eq "listvms")
                {
                        my %vm_state_strings = ("poweredOn" => "UP", "poweredOff" => "DOWN", "suspended" => "SUSPENDED");
                        my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['name', 'runtime']);

                        if (!defined($vm_views))
                           {
                           print "Runtime error\n";
                           exit 2;
                           }

                        if (!defined($vm_views))
                           {
                           print "There are no VMs.\n";
                           exit 2;
                           }

                        my $up = 0;
                        $output = '';

                        foreach my $vm (@$vm_views)
                        {
                                my $vm_state = $vm_state_strings{$vm->runtime->powerState->val};
                                if ($vm_state eq "UP")
                                {
                                        $up++;
                                        $output = $output . $vm->name . "(0), ";
                                }
                                else
                                {
                                        $output = $vm->name . "(" . $vm_state . "), " . $output;
                                }
                        }

                        chop($output);
                        chop($output);
                        $state = 0;
                        $output = $up .  "/" . @$vm_views . " VMs up: " . $output;
                        $perfdata = $perfdata . " vmcount=" . $up . ";" . $perf_thresholds . ";;";

                        if ( $perf_thresholds eq 1 )
                           {
                           $state = check_against_threshold($up);
                           }
                }
                elsif ($subselect eq "listhost")
                {
# Reminder: Wie bei host_runtime_info die virtuellen Maschinen als performancedaten ausgeben
                        my %host_state_strings = ("poweredOn" => "UP", "poweredOff" => "DOWN", "suspended" => "SUSPENDED", "standBy" => "STANDBY", "MaintenanceMode" => "Maintenance Mode");
                        my $host_views = Vim::find_entity_views(view_type => 'HostSystem', begin_entity => $cluster_view, properties => ['name', 'runtime.powerState']);

                        if (!defined($host_views))
                           {
                           print "Runtime error\n";
                           exit 2;
                           }

                        if (!defined($host_views))
                           {
                           print "There are no hosts.\n" ;
                           exit 2;
                           }

                        my $up = 0;
                        my $unknown = 0;
                        $output = '';

                        foreach my $host (@$host_views) {
                                $host->update_view_data(['name', 'runtime.powerState']);
                                my $host_state = $host_state_strings{$host->get_property('runtime.powerState')->val};
                                $unknown += $host_state eq "3";
                                if ($host_state eq "UP" && $host_state eq "Maintenance Mode") {
                                        $up++;
                                        $output = $output . $host->name . "(UP), ";
                                } else
                                {
                                        $output = $host->name . "(" . $host_state . "), " . $output;
                                }
                        }

                        chop($output);
                        chop($output);
                        $state = 0;
                        $output = $up .  "/" . @$host_views . " Hosts up: " . $output;
                        $perfdata = $perfdata . " vmcount=" . $up . ";" . $perf_thresholds . ";;";

                        if ( $perf_thresholds eq 1 )
                           {
                           $state = check_against_threshold($up);
                           }

                        $state = 3 if ($state == 0 && $unknown);
                }
                elsif ($subselect eq "status")
                {
                        if (defined($cluster_view->overallStatus))
                        {
                                my $status = $cluster_view->overallStatus->val;
                                $output = "overall status=" . $status;
                                $state = check_health_state($status);
                        }
                        else
                        {
                                $output = "Insufficient rights to access status info on the DC\n";
                                $state = 1;
                        }
                }
                elsif ($subselect eq "issues")
                {
                        my $issues = $cluster_view->configIssue;
                        my $issues_count = 0;

                        $output = '';
                        if (defined($issues))
                        {
                                foreach (@$issues)
                                {
                                        if (defined($blacklist))
                                        {
                                                my $name = ref($_);
                                                next if ($blacklist =~ m/(^|\s|\t|,)\Q$name\E($|\s|\t|,)/);
                                        }
                                        $output = $output . format_issue($_) . "; ";
                                        $issues_count++;
                                }
                        }

                        if ($output eq '')
                        {
                                $state = 0;
                                $output = 'No config issues';
                        }
                        $perfdata = $perfdata . " issues=" . $issues_count;
                }
                else
                {
                get_me_out("Unknown CLUSTER RUNTIME subselect");
                }
        }
     else
        {
                my %cluster_maintenance_state = (0 => "no", 1 => "yes");
                my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', begin_entity => $cluster_view, properties => ['name', 'runtime.powerState']);
                my $up = 0;

                if (defined($vm_views))
                {
                        foreach my $vm (@$vm_views) {
                                $up += $vm->get_property('runtime.powerState')->val eq "poweredOn";
                        }
                        $perfdata = $perfdata . " vmcount=" . $up . ";" . $perf_thresholds . ";;";
                        $output = $up . "/" . @$vm_views . " VMs up";
                }
                else
                {
                        $output = "No VMs installed";
                }

                my $AlertCount = 0;
                my $SensorCount = 0;
                my ($cpuStatusInfo, $storageStatusInfo, $memoryStatusInfo, $numericSensorInfo);

                $state = 0;
                $output = $output . ", overall status=" . $cluster_view->overallStatus->val . ", " if (defined($cluster_view->overallStatus));

                my $issues = $cluster_view->configIssue;
                if (defined($issues))
                {
                        $output = $output . @$issues . " config issue(s)";
                }
                else
                {
                        $output = $output . "no config issues";
                }
        }

        return ($state, $output);
}




