#!/usr/bin/env perl
use strict;
use warnings;

my $cmd = "apt-get --just-print dist-upgrade";
my %metrics;

open(my $fh, '-|', $cmd) or die $!;
while(my $line = <$fh>) {
    if ($line =~ /Inst \S+ \S+ \(\S+ (.+) \[(\S+)\]\)/) {
        my $k = sprintf("apt_upgrades_pending{origin=\"%s\", arch=\"%s\"}", $1, $2); 
        if (!exists $metrics{$k}) {
            $metrics{$k} = 1;
        } else {
            $metrics{$k}++;
        }
    }
}

if (%metrics) {
    # print apt metrics
    while(my($k, $v) = each %metrics) {
        printf("%s %d\n", $k, $v)
    }
}
else {
    print("apt_upgrades_pending{origin=\"\",arch=\"\"} 0\n");
}

# print reboot required metric
if (-e "/var/run/reboot-required") {
    print("node_reboot_required 1\n")
}
else {
    print("node_reboot_required 0\n")
}
