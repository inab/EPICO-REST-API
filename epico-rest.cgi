#!/usr/bin/perl -w
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jmfernandez@cnio.es)

use strict;
use warnings 'all';

BEGIN { $ENV{DANCER_APPHANDLER} = 'PSGI';}
use Dancer2;
use Dancer2::FileUtils;
use File::Spec;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin,"local");

# For some reason Apache SetEnv directives don't propagate
# correctly to the dispatchers, so forcing PSGI and env here
# is safer.
set apphandler => 'PSGI';
set environment => 'production';

# Removing the extension
my $psgi = Dancer2::FileUtils::path($FindBin::Script);
my($volume,$directories,$file) = File::Spec->splitpath($psgi);

my $rdot = rindex($file,'.');
if($rdot != -1) {
	$file = substr($file,0,$rdot);
	
	$psgi = File::Spec->catpath($volume,$directories,$file);
}
# Adding the new extension
$psgi .= '.psgi';

die "Unable to find EPICO REST API script: $psgi" unless(-r $psgi);

# This is for plain CGIs
use Plack::Runner;
Plack::Runner->run($psgi);
