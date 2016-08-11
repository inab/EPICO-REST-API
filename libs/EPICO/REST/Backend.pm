#!/usr/bin/perl

# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jmfernandez@cnio.es)

use strict;
use warnings 'all';

# All the backends must inherit from this class, and implement its API
package EPICO::REST::Backend;

use Carp;
use Config::IniFiles;
use Log::Log4perl;
use Scalar::Util qw();

sub new($$) {
	# Very special case for multiple inheritance handling
	# This is the seed
	my($facet)=shift;
	my($class)=ref($facet) || $facet;
	
	my $iniFile = shift;
	my $ini = shift;
	
	$ini = Config::IniFiles->new( -file => $iniFile )  unless(defined($ini));
	
	Carp::croak("Second parameter must be an instance of Config::IniFiles")  unless(Scalar::Util::blessed($ini) && $ini->isa('Config::IniFiles'));
	
	my %href = ();
	
	$href{iniFile} = $iniFile;
	$href{ini} = $ini;
	$href{LOG} = Log::Log4perl->get_logger(__PACKAGE__);
	
	return bless(\%href,$class);
}

# It returns the data model
sub getModelFromDomain() {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getAvailableCVs() {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getCV($) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getCVterms($;\@) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getFilteredCVterms(\@) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getCVsFromColumn($$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getCVtermsFromColumn($$$;\@) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getSampleTrackingData(;$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getDonors(;$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getSpecimens(;$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getSamples(;$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getExperiments(;$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getAnalysisMetadata(;$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getDataFromCoords($$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getGenomicLayout($) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getGenomicLayoutFromCoords($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  unless(ref($self));
	
	my($chromosome,$chromosome_start,$chromosome_end) = @_;
	
	my $rangeData = {
		'range'	=>	[
			{
				'chr'	=>	$chromosome,
				'start'	=>	$chromosome_start,
				'end'	=>	$chromosome_end
			}
		]
	};
	
	return $self->getGenomicLayout($rangeData);
}

sub getDataCountFromCoords($$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub getDataStatsFromCoords($$$) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub queryFeatures($) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

sub suggestFeatures($) {
	Carp::croak((caller(0))[3]. 'is an unimplemented method!');
}

1;
