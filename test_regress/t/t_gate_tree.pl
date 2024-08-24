#!/usr/bin/env perl
if (!$::Driver) { use FindBin; exec("$FindBin::Bin/bootstrap.pl", @ARGV, $0); die; }
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# Copyright 2003 by Wilson Snyder. This program is free software; you
# can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
use IO::File;
#use Data::Dumper;
use strict;
use vars qw($Self);

scenarios(simulator => 1);

my $width = 64 * ($ENV{VERILATOR_TEST_WIDTH} || 4);
my $vars = 64;

$Self->{cycles} = ($Self->{benchmark} ? 1_000_000 : 100);
$Self->{sim_time} = $Self->{cycles} * 10 + 1000;

sub gen {
    my $filename = shift;

    my $fh = IO::File->new(">$filename");
    $fh->print("// Generated by t_gate_tree.pl\n");
    $fh->print("module t (clk);\n");
    $fh->print("  input clk;\n");
    $fh->print("\n");
    $fh->print("  integer cyc=0;\n");
    $fh->print("  reg reset;\n");
    $fh->print("\n");

    my %tree;
    my $fanin = 8;
    my $stages = int(log($vars) / log($fanin) + 0.99999) + 1;
    my $result = 0;
    for (my $n = 0; $n < $vars; $n++) {
        $result += ($n || 1);
        $tree{0}{$n}{$n} = 1;
        my $nl = $n;
        for (my $stage=1; $stage < $stages; $stage++) {
            my $lastn = $nl;
            $nl = int($nl / $fanin);
            $tree{$stage}{$nl}{$lastn} = 1;
        }
    }
    #print Dumper(\%tree);

    $fh->print("\n");
    my $workingset = 0;
    foreach my $stage (sort { $a <=> $b} keys %tree) {
        foreach my $n (sort { $a <=> $b} keys %{$tree{$stage}}) {
            $fh->print(    "   reg [" . ($width - 1) . ":0] v${stage}_${n};\n");
            $workingset += int($width/8 + 7);
        }
    }

    $fh->print("\n");
    $fh->print("   always @ (posedge clk) begin\n");
    $fh->print("      cyc <= cyc + 1;\n");
    $fh->print("`ifdef TEST_VERBOSE\n");
    $fh->print("         \$write(\"[%0t] rst=%0x  v0_0=%0x  v1_0=%0x  result=%0x\\n\""
               .", \$time, reset, v0_0, v1_0, v" . ($stages - 1) . "_0);\n");
    $fh->print("`endif\n");
    $fh->print("      if (cyc==0) begin\n");
    $fh->print("         reset <= 1;\n");
    $fh->print("      end\n");
    $fh->print("      else if (cyc==10) begin\n");
    $fh->print("         reset <= 0;\n");
    $fh->print("      end\n");
    $fh->print("`ifndef SIM_CYCLES\n");
    $fh->print(" `define SIM_CYCLES 99\n");
    $fh->print("`endif\n");
    $fh->print("      else if (cyc==`SIM_CYCLES) begin\n");
    $fh->print("         if (v" . ($stages - 1) . "_0 != ${width}'d${result}) \$stop;\n");
    $fh->print("         \$write(\"VARS=${vars} WIDTH=${width}"
               ." WORKINGSET=" . (int($workingset / 1024)) . "KB\\n\");\n");
    $fh->print('         $write("*-* All Finished *-*\n");', "\n");
    $fh->print('         $finish;', "\n");
    $fh->print("      end\n");
    $fh->print("   end\n");

    $fh->print("\n");
    for (my $n=0; $n<$vars; $n++) {
        $fh->print("   always @ (posedge clk)"
                   . " v0_${n} <= reset ? ${width}'d" . (${n} || 1) . " : v0_"
                   . ((int($n / $fanin) * $fanin) + (($n + 1) % $fanin)) . ";\n");
    }

    foreach my $stage (sort {$a<=>$b} keys %tree) {
        next if $stage == 0;
        $fh->print("\n");
        foreach my $n (sort {$a<=>$b} keys %{$tree{$stage}}) {
            $fh->print("   always @ (posedge clk)"
                       . " v${stage}_${n} <=");
            my $op = "";
            foreach my $ni (sort {$a<=>$b} keys %{$tree{$stage}{$n}}) {
                $fh->print($op . " v" . (${stage} - 1) . "_${ni}");
                $op = " +";
            }
            $fh->print(";\n");
        }
    }

    $fh->print("endmodule\n");
}

top_filename("$Self->{obj_dir}/t_gate_tree.v");

gen($Self->{top_filename});

compile(
    v_flags2 => ["+define+SIM_CYCLES=$Self->{cycles}",],
    verilator_flags2=>["--stats --x-assign fast --x-initial fast",
                       "-Wno-UNOPTTHREADS"],
    );

execute(
    all_run_flags => ["+verilator+prof+exec+start+100",
                      " +verilator+prof+exec+window+2",
                      " +verilator+prof+exec+file+$Self->{obj_dir}/profile_exec.dat",
                      " +verilator+prof+vlt+file+$Self->{obj_dir}/profile.vlt",
                      ],
    );

ok(1);
1;
