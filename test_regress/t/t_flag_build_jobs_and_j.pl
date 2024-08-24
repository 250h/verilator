#!/usr/bin/env perl
if (!$::Driver) { use FindBin; exec("$FindBin::Bin/bootstrap.pl", @ARGV, $0); die; }
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# Copyright 2022 by Antmicro Ltd.. This program is free software; you
# can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

scenarios(simulator => 1);
top_filename("t/t_flag_make_cmake.v");

compile(
    verilator_flags2 => ['--exe --cc --build -j 10 --build-jobs 2 --stats',
                         '../' . $Self->{main_filename}],
    );

execute(
    );

file_grep($Self->{stats}, qr/Build jobs: 2/);

ok(1);
1;
