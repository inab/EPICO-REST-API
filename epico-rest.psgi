#!/usr/bin/perl
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jose.m.fernandez@bsc.es)

use strict;
use warnings 'all';

use File::Spec;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin,"libs");

use EPICO::REST::API;
use Plack::Builder;
builder {
# Enabling this we get some issues, so disabled for now
	enable 'CrossOrigin', origins => '*', headers => '*';
	enable 'Deflater', content_type => ['text/plain','text/css','text/html','text/javascript','application/javascript','application/json'];
	mount '/'    => EPICO::REST::API->to_app;
};
