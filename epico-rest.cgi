#!/usr/bin/perl -w
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jmfernandez@cnio.es)

use strict;
use warnings 'all';

BEGIN { $ENV{DANCER_APPHANDLER} = 'PSGI';}
use Dancer2;
use Dancer2::FileUtils;
use FindBin;
# For some reason Apache SetEnv directives dont propagate
# correctly to the dispatchers, so forcing PSGI and env here
# is safer.
set apphandler => 'PSGI';
set environment => 'production';
my $psgi = Dancer2::FileUtils::path($FindBin::Script.'.psgi');
die "Unable to find EPICO REST API script: $psgi" unless(-r $psgi);

# This is for plain CGIs
use Plack::Runner;
Plack::Runner->run($psgi);
