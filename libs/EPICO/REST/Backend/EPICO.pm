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

# It returns the data model stored in the database
sub getAvailableCVs() {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my(undef,$metaCVConcept,undef) = BP::Loader::Mapper::Elasticsearch::__getMetaConcepts($self->{model});
	
	my $mapper = $self->{mapper};
	
	my $scroll = $mapper->queryConcept($metaCVConcept,{});
	
	my @CVs = ();
	until($scroll->is_finished) {
		$scroll->refill_buffer();
		my @docs = $scroll->drain_buffer();
		
		#return $docs[0]->{_source};
		foreach my $doc (@docs) {
			$doc->{_source}{'cv_id'} = $doc->{_id};
			push(@CVs,$doc->{_source});
		}
	}
	
	return \@CVs;
}

sub _getCVinternal($) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($cv) = @_;
	my $p_cv = $self->getCV($cv);
	
	my $retval = undef;
	
	if(defined($p_cv)) {
		if(exists($p_cv->{'includes'})) {
			$retval = $p_cv->{'includes'};
		} else {
			$retval = [ $cv ];
		}
	}
	
	return $retval;
}

sub getCV($) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my $cv_id = shift;
	$cv_id = [ $cv_id ]  unless(ref($cv_id) eq 'ARRAY');
	
	my(undef,$metaCVConcept,undef) = BP::Loader::Mapper::Elasticsearch::__getMetaConcepts($self->{model});
	
	my $mapper = $self->{mapper};
	
	my $scroll = $mapper->queryConcept($metaCVConcept,{'query' => { 'terms' => { '_id' => $cv_id }}});
	
	my @CVs = ();
	my $doc = undef;
	until($scroll->is_finished) {
		$scroll->refill_buffer();
		my @docs = $scroll->drain_buffer();
		
		if(scalar(@docs) > 0) {
			$docs[0]->{_source}{'cv_id'} = $docs[0]->{_id};
			$doc = $docs[0]->{_source};
		}
		last;
	}
	
	return $doc;
}

sub getCVterms($;\@) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($cv_id,$theUris) = @_;
	my @cv_ids = ();
	my @temp_cv_ids = ref($cv_id) eq 'ARRAY' ? @{$cv_id} : ( $cv_id );
	
	my $oneFound = undef;
	if(scalar(@temp_cv_ids) > 0) {
		foreach my $temp_cv_id (@temp_cv_ids) {
			my $p_res_cv = $self->_getCVinternal($temp_cv_id);
			if(defined($p_res_cv)) {
				push(@cv_ids,@{$p_res_cv});
				$oneFound = 1;
			}
		}
	} else {
		# No input, but no failure
		$oneFound = 1;
	}
	
	my $doc = undef;
	if($oneFound) {
		if(scalar(@cv_ids)>0) {
			my(undef,undef,$metaCVTermConcept) = BP::Loader::Mapper::Elasticsearch::__getMetaConcepts($self->{model});
			
			my $mapper = $self->{mapper};
			
			my $p_filters =  [{
				'terms' => {
					'ont' => \@cv_ids
				}
			}];
			
			push(@{$p_filters},{
				'terms' => {
					'alt_id' => $theUris
				}
			})  if(ref($theUris) eq 'ARRAY');
			
			my $scroll = $mapper->queryConcept($metaCVTermConcept,{
				'query' => {
					'filtered' =>  {
						'query' => {
							'match_all' => {}
						},
						'filter' => {
							'and' => {
								'filters' => $p_filters
							}
						}
					}
				},
				'fields' => ['term','term_uri','name','ont']
			});
			
			my @CVterms = ();
			until($scroll->is_finished) {
				$scroll->refill_buffer();
				my @docs = $scroll->drain_buffer();
				
				if(scalar(@docs) > 0) {
					$doc = \@CVterms;
					foreach my $doc (@docs) {
						my $p_fields = $doc->{fields};
						push(@CVterms,{
							'name'	=>	$p_fields->{'name'}[0],
							'term'	=>	$p_fields->{'term'}[0],
							'term_uri'	=>	$p_fields->{'term_uri'}[0],
							'ont'	=>	$p_fields->{'ont'}[0],
						});
					}
				}
			}
		} else {
			$doc = [];
		}
	}
	
	return $doc;
}

sub getCVsFromColumn($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($conceptDomainName,$conceptName,$columnName) = @_;
	
	my $dbModel = $self->getModel();
	
	my $retval = undef;
	
	if(exists($dbModel->{'domains'}{$conceptDomainName})) {
		my $p_conceptDomain = $dbModel->{'domains'}{$conceptDomainName};
		if(exists($p_conceptDomain->{'concepts'}{$conceptName})) {
			my $p_concept = $p_conceptDomain->{'concepts'}{$conceptName};
			if(exists($p_concept->{'columns'}{$columnName})) {
				my $p_column = $p_concept->{'columns'}{$columnName};
				
				$retval = [];
				
				if(exists($p_column->{'restrictions'}) && exists($p_column->{'restrictions'}{'cv'})) {
					$retval = $self->_getCVinternal($p_column->{'restrictions'}{'cv'});
				}
			}
		}
	}
	
	return $retval;
}

sub getCVtermsFromColumn($$$;\@) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($conceptDomainName,$conceptName,$columnName,$theUris) = @_;
	
	my $p_CVnames = $self->getCVsFromColumn($conceptDomainName,$conceptName,$columnName);
	
	my $retval = undef;
	
	if(defined($p_CVnames)) {
		$retval = $self->getCVterms($p_CVnames,$theUris);
	}
	
	return $retval;
}

1;
