#!/usr/bin/env perl
if (!$::Driver) { use FindBin; exec("$FindBin::Bin/bootstrap.pl", @ARGV, $0); die; }
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# Copyright 2003-2009 by Wilson Snyder. This program is free software; you
# can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

scenarios(simulator => 1);

top_filename("t/t_trace_enum.v");

compile(
    verilator_flags2 => ['--cc --trace-fst --output-split-ctrace 1'],
    );

execute(
    );

fst_identical($Self->trace_filename, $Self->{golden_filename});

# Five $attrbegin expected:
# - state_t declaration
# - t.v_enumed
# - t.sink.state
# - other_state_t declaration
# - t.v_other_enumed
file_grep_count($Self->{golden_filename}, qr/attrbegin/, 5);

ok(1);
1;
