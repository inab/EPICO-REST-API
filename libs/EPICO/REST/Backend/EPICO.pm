#!/usr/bin/perl

# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jmfernandez@cnio.es)

use strict;
use warnings 'all';

package EPICO::REST::Backend::EPICO;

use base qw(EPICO::REST::Backend);

use BP::Model;
use BP::Loader::Tools;
use BP::Loader::CorrelatableConcept;
use BP::Loader::Mapper;
#use BP::Loader::Mapper::Autoload::Relational;
use BP::Loader::Mapper::Autoload::Elasticsearch;
use BP::Loader::Mapper::Elasticsearch;
#use BP::Loader::Mapper::Autoload::MongoDB;

use File::Basename;
use File::Spec;

use Log::Log4perl;

use constant ELASTICSEARCH_STORAGE_MODEL	=>	'elasticsearch';

# This is the empty constructor
sub new($$) {
	my($self)=shift;
	my($class)=ref($self) || $self;
	
	$self = $class->SUPER::new(@_)  unless(ref($self));
	
	my $LOG = Log::Log4perl->get_logger(__PACKAGE__);
	
	$self->{LOG} = $LOG;
	
	my $ini = $self->{ini};
	
	# Now, let's parse the data model
	my $iniFile = $self->{iniFile};
	my $modelFile = $ini->val($BP::Loader::Mapper::DEFAULTSECTION,'model');
	# Setting up the right path on relative cases
	
	$modelFile = File::Spec->catfile(File::Basename::dirname($iniFile),$modelFile)  unless(File::Spec->file_name_is_absolute($modelFile));
	$LOG->debug("Parsing model $modelFile...");
	
	my $model = undef;
	eval {
		$model = BP::Model->new($modelFile,undef,1);
	};
	
	if($@) {
		$LOG->logdie('ERROR: Model parsing and validation failed. Reason: '.$@);
	}
	$LOG->debug("\tDONE!");
	
	$self->{model} = $model;
	
	my $loadModelNames = $ini->val($BP::Loader::Mapper::SECTION,'loaders');
	
	my @loadModels = ();
	my %storageModels = ();
	foreach my $loadModelName (split(/,/,$loadModelNames)) {
		unless(exists($storageModels{$loadModelName})) {
			$storageModels{$loadModelName} = BP::Loader::Mapper->newInstance($loadModelName,$model,$ini);
			push(@loadModels,$loadModelName);
		}
	}
	
	$self->{mapper} = $storageModels{ELASTICSEARCH_STORAGE_MODEL()};
	
	return $self;
}

# It returns the data model stored in the database
sub getModel() {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($modelConcept,undef,undef) = BP::Loader::Mapper::Elasticsearch::__getMetaConcepts($self->{model});
	
	my $mapper = $self->{mapper};
	
	my $scroll = $mapper->queryConcept($modelConcept,{});
	
	until($scroll->is_finished) {
		$scroll->refill_buffer();
		my @docs = $scroll->drain_buffer();
		
		return $docs[0]->{_source};
	}
	
	return undef;
}

1;
