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
sub getModelFromDomain() {
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
				'fields' => ['term','term_uri','name','ancestors','ont']
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
							'ancestors'	=>	$p_fields->{'ancestors'},
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

sub getFilteredCVterms(\@) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($p_theTerms) = @_;
	my $doc = undef;
	
	my(undef,undef,$metaCVTermConcept) = BP::Loader::Mapper::Elasticsearch::__getMetaConcepts($self->{model});
	
	my $mapper = $self->{mapper};
	
	my @CVterms = ();
	
	# Don't query with an empty array, it doesn't make sense
	if(scalar(@{$p_theTerms}) > 0) {
		my $p_filter =  {
			'terms' => {
				'term' => $p_theTerms
			}
		};
		
		my $scroll = $mapper->queryConcept($metaCVTermConcept,{
			'query' => {
				'filtered' =>  {
					'query' => {
						'match_all' => {}
					},
					'filter' => $p_filter
				}
			},
			'fields' => ['term','term_uri','name','parents','ont']
		});
		
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
						'parents'	=>	$p_fields->{'parents'},
						'ont'	=>	$p_fields->{'ont'}[0],
					});
				}
			}
		}
	} else {
		$doc = [];
	}
	
	return $doc;
}

sub getCVsFromColumn($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($conceptDomainName,$conceptName,$columnName) = @_;
	
	my $dbModel = $self->getModelFromDomain();
	
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

use constant {
	SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN	=>	'sdata',
	LABORATORY_EXPERIMENTS_CONCEPT_DOMAIN	=>	'lab',
};

use constant {
	DONOR_CONCEPT	=>	'donor',
	SPECIMEN_CONCEPT	=>	'specimen',
	SAMPLE_CONCEPT	=>	'sample',
	FEATURES_CONCEPT	=>	'features',
};

use constant {
	DONOR_CONCEPT_TYPE	=>	SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN() . '.' . DONOR_CONCEPT(),
	SPECIMEN_CONCEPT_TYPE	=>	SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN() . '.' . SPECIMEN_CONCEPT(),
	SAMPLE_CONCEPT_TYPE	=>	SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN() . '.' . SAMPLE_CONCEPT(),
};

my %concept2id = (
	DONOR_CONCEPT_TYPE()	=>	'donor_id',
	SPECIMEN_CONCEPT_TYPE()	=>	'specimen_id',
	SAMPLE_CONCEPT_TYPE()	=>	'sample_id',
);

use constant	EXPERIMENT_ID	=>	'experiment_id';

my %conceptDomain2id = (
	LABORATORY_EXPERIMENTS_CONCEPT_DOMAIN()	=>	EXPERIMENT_ID(),
);

use constant {
	METADATA_COLLECTION	=>	'metadata',
	PRIMARY_COLLECTION	=>	'primary',
	EXTERNAL_COLLECTION	=>	'external',
};

use constant	ANALYSIS_ID	=>	'analysis_id';

my %collection2id = (
	METADATA_COLLECTION()	=>	ANALYSIS_ID(),
	PRIMARY_COLLECTION()	=>	ANALYSIS_ID(),
);

my %collection2agg = (
	PRIMARY_COLLECTION()	=>	'analyses',
);

use constant	ALL_IDS	=>	'_all';

use constant {
	REGION_FEATURE_GENE	=>	'gene',
	REGION_FEATURE_TRANSCRIPT	=>	'transcript',
	REGION_FEATURE_UTR	=>	'UTR',
	REGION_FEATURE_START_CODON	=>	'start_codon',
	REGION_FEATURE_STOP_CODON	=>	'stop_codon',
	REGION_FEATURE_EXON	=>	'exon',
	REGION_FEATURE_CDS	=>	'CDS',
	REGION_FEATURE_SELENOCYSTEINE	=>	'Selenocysteine',
};

use constant REGION_FEATURES => [ REGION_FEATURE_GENE , REGION_FEATURE_TRANSCRIPT, REGION_FEATURE_UTR, REGION_FEATURE_EXON, REGION_FEATURE_CDS, REGION_FEATURE_START_CODON, REGION_FEATURE_STOP_CODON ];

sub getSampleTrackingData(;$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($onlyIds) = @_;
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	
	# Getting the correspondence from concepts to collections, so the queries can be issued
	my @concepts = ();
	foreach my $conceptDomainName ((SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN(),LABORATORY_EXPERIMENTS_CONCEPT_DOMAIN())) {
		
		if(exists($dbModel->{'domains'}{$conceptDomainName})) {
			my $conceptDomain = $model->getConceptDomain($conceptDomainName);
			
			if(defined($conceptDomain)) {
				my $p_concepts = $conceptDomain->concepts();
				push(@concepts,@{$p_concepts})  if(defined($p_concepts));
			}
		}
	}
	
	my $mapper = $self->{mapper};
	
	my $retval = undef;
	my $scroll = $mapper->queryConcept(\@concepts,{});
	my @metadata = ();
	until($scroll->is_finished) {
		$scroll->refill_buffer();
		my @docs = $scroll->drain_buffer();
		
		if(scalar(@docs) > 0) {
			$retval = \@metadata;
			foreach my $doc (@docs) {
				
				my $data = undef;
				
				if($onlyIds) {
					my $key = exists($concept2id{$doc->{_type}}) ? $concept2id{$doc->{_type}} : EXPERIMENT_ID();
					$data = {
						'_type'	=>	$doc->{_type},
						$key	=>	$doc->{_source}{$key}
					};
				} else {
					$doc->{_source}{_type} = $doc->{_type};
					$data = $doc->{_source};
				}
				
				push(@metadata,$data);
			}
		}
	}
	return $retval;
}

sub _getFromConcept($$;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($conceptDomainName, $conceptName,$key_id,$onlyIds) = @_;
	
	$key_id = undef  if(defined($key_id) && $key_id eq ALL_IDS());
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'domains'}{$conceptDomainName})) {
		my $conceptDomain = $model->getConceptDomain($conceptDomainName);
		
		if(defined($conceptDomain)) {
			my $concept = undef;
			my $key_name = undef;
			
			if(defined($conceptName)) {
				$concept = $conceptDomain->conceptHash()->{$conceptName};
				$key_name = $concept2id{$concept->id()};
			} else {
				$concept = $conceptDomain->concepts();
				$key_name = $conceptDomain2id{$conceptDomainName};
			}
			
			my $query_body = defined($key_id) ? { "query" => { "filtered" => { "query" => { "match_all" => {} }, "filter" => { "term" => { $key_name  => $key_id } } } } } : {};
			
			my $mapper = $self->{mapper};
			
			my $scroll = $mapper->queryConcept($concept,$query_body);
			
			my @metadata = ();
			until($scroll->is_finished) {
				$scroll->refill_buffer();
				my @docs = $scroll->drain_buffer();
				
				if(scalar(@docs) > 0) {
					if(defined($key_id)) {
						my $doc = $docs[0];
						$doc->{_source}{_type} = $doc->{_type};
						$retval = $doc->{_source};
						last;
					} else {
						$retval = \@metadata;
						foreach my $doc (@docs) {
							my $data = undef;
							if($onlyIds) {
								$data = {
									$key_name	=>	$doc->{_source}{$key_name}
								};
							} else {
								$data = $doc->{_source};
							}
							$data->{_type} = $doc->{_type};
							
							push(@metadata,$data);
						}
					}
				}
			}
		}
	}
	
	return $retval;
}

sub getDonors(;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($donor_id,$onlyIds) = @_;
	
	return $self->_getFromConcept(SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN,DONOR_CONCEPT,$donor_id,$onlyIds);
}

sub getSpecimens(;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($specimen_id,$onlyIds) = @_;
	
	return $self->_getFromConcept(SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN,SPECIMEN_CONCEPT,$specimen_id,$onlyIds);
}

sub getSamples(;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($sample_id,$onlyIds) = @_;
	
	return $self->_getFromConcept(SAMPLE_TRACKING_DATA_CONCEPT_DOMAIN,SAMPLE_CONCEPT,$sample_id,$onlyIds);
}

sub getExperiments(;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($experiment_id,$onlyIds) = @_;
	
	return $self->_getFromConcept(LABORATORY_EXPERIMENTS_CONCEPT_DOMAIN,undef,$experiment_id,$onlyIds);
}

sub _getFromCollection($;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($collectionName,$key_id,$onlyIds) = @_;
	
	$key_id = undef  if(defined($key_id) && $key_id eq ALL_IDS());
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'collections'}{$collectionName})) {
		my $collection = $model->getCollection($collectionName);
		
		if(defined($collection)) {
			my $key_name = $collection2id{$collectionName};
			
			my $query_body = defined($key_id) ? { "query" => { "filtered" => { "query" => { "match_all" => {} }, "filter" => { "term" => { $key_name  => $key_id } } } } } : {};
			
			my $mapper = $self->{mapper};
			
			my $scroll = $mapper->queryCollection($collection,$query_body);
			
			my @metadata = ();
			until($scroll->is_finished) {
				$scroll->refill_buffer();
				my @docs = $scroll->drain_buffer();
				
				if(scalar(@docs) > 0) {
					if(defined($key_id)) {
						my $doc = $docs[0];
						$doc->{_source}{_type} = $doc->{_type};
						$retval = $doc->{_source};
						last;
					} else {
						$retval = \@metadata;
						foreach my $doc (@docs) {
							my $data = undef;
							if($onlyIds) {
								$data = {
									$key_name	=>	$doc->{_source}{$key_name}
								};
							} else {
								$data = $doc->{_source};
							}
							$data->{_type} = $doc->{_type};
							
							push(@metadata,$data);
						}
					}
				}
			}
		}
	}
	
	return $retval;
}

sub getAnalysisMetadata(;$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($analysis_id,$onlyIds) = @_;
	
	return $self->_getFromCollection(METADATA_COLLECTION,$analysis_id,$onlyIds);
}


sub _genShouldQuery($;$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($rangeData,$prefix) = @_;
	
	my $flankingWindowSize = exists($rangeData->{flankingWindowSize}) ? $rangeData->{flankingWindowSize} : 0;
	
	my $rangeQueryArr = $rangeData->{range};
	$rangeQueryArr = [ $rangeQueryArr ]  unless(ref($rangeQueryArr) eq 'ARRAY');
	
	my $chromosome_name = 'chromosome';
	my $chromosome_start_name = 'chromosome_start';
	my $chromosome_end_name = 'chromosome_end';
	if(defined($prefix)) {
		$chromosome_name = $prefix . '.' . $chromosome_name;
		$chromosome_start_name = $prefix . '.' . $chromosome_start_name;
		$chromosome_end_name = $prefix . '.' . $chromosome_end_name;
	}
	
	my @shouldQuery = ();
	
	foreach my $q (@{$rangeQueryArr}) {
		my $qStart = $q->{'start'} - $flankingWindowSize;
		my $qEnd = $q->{'end'} + $flankingWindowSize;
		
		my $termQuery = {
			$chromosome_name	=>	$q->{'chr'}
		};
		
		my $commonRange = {
			'gte'	=>	$qStart,
			'lte'	=>	$qEnd
		};
		
		my $chromosome_start_range = {
			$chromosome_start_name	=>	$commonRange
		};
		
		my $chromosome_end_range = {
			$chromosome_end_name	=>	$commonRange
		};
		
		my $chromosome_start_lte_range = {
			$chromosome_start_name	=>	{
				'lte'	=>	$qEnd
			}
		};
		
		my $chromosome_end_gte_range = {
			$chromosome_end_name	=>	{
				'gte'	=>	$qStart
			}
		};
		
		push(@shouldQuery,{
			'bool'	=>	{
				'must'	=>	[
					{
						'term'	=>	$termQuery
					},
					{
						'bool'	=>	{
							'should'	=>	[
								{
									'range'	=>	$chromosome_start_range
								},
								{
									'range'	=>	$chromosome_end_range
								},
								{
									'bool'	=>	{
										'must'	=>	[
											{
												'range'	=>	$chromosome_start_lte_range
											},
											{
												'range'	=>	$chromosome_end_gte_range
											}
										]
									}
								}
							]
						}
					}
				]
			}
		});
	}
	
	my $p_shouldQuery = undef;
	if(defined($prefix)) {
		$p_shouldQuery = {
			'nested'	=> {
				'path'	=>	$prefix,
				'filter'	=>	{
					'bool'	=>	{
						'should'	=>	\@shouldQuery
					}
				}
			}
		};
	} else {
		$p_shouldQuery = \@shouldQuery;
	}
	
	return $p_shouldQuery;
}


sub _getDataFromCollection($$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($collectionName,$rangeData) = @_;
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'collections'}{$collectionName})) {
		my $collection = $model->getCollection($collectionName);
		
		if(defined($collection)) {
			my $shouldQuery = $self->_genShouldQuery($rangeData);
			my $query_body = {
				'query'	=>	{
					'filtered'	=>	{
						'filter'	=>	{
							'bool'	=>	{
								'should'	=>	$shouldQuery
							}
						}
					}
				}
			};
			
			my $mapper = $self->{mapper};
			
			my $scroll = $mapper->queryCollection($collection,$query_body);
			
			my @dataArr = ();
			until($scroll->is_finished) {
				$scroll->refill_buffer();
				my @docs = $scroll->drain_buffer();
				
				if(scalar(@docs) > 0) {
					$retval = \@dataArr;
					foreach my $doc (@docs) {
						my $data = $doc->{_source};
						$data->{_type} = $doc->{_type};
						
						push(@dataArr,$data);
					}
				}
			}
		}
	}
	
	return $retval;
}

sub getDataFromCoords($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
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
	
	return $self->_getDataFromCollection(PRIMARY_COLLECTION,$rangeData);
}

sub _getDataCountFromCollection($$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($collectionName,$rangeData) = @_;
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'collections'}{$collectionName})) {
		my $collection = $model->getCollection($collectionName);
		
		if(defined($collection)) {
			my $shouldQuery = $self->_genShouldQuery($rangeData);
			my $key_name = $collection2id{$collectionName};
			my $query_body = {
				'query'	=>	{
					'filtered'	=>	{
						'filter'	=>	{
							'bool'	=>	{
								'should'	=>	$shouldQuery
							}
						}
					}
				},
				'aggregations'	=>	{
					'analyses'	=>	{
						'terms'	=>	{
							'field'	=>	$key_name,
							'size'	=>	0
						}
					}
				}
			};
			
			my $mapper = $self->{mapper};
			
			my $results = $mapper->immediateQueryCollection($collection,$query_body,'count',undef,{'request_cache' => boolean::true });
			
			if(exists($results->{'aggregations'})) {
				my @dataArr = ();
				foreach my $data (@{$results->{'aggregations'}->{'analyses'}->{'buckets'}}) {
				
					push(@dataArr,$data);
				}
				$retval = \@dataArr;
			}
		}
	}
	
	return $retval;
}

sub getDataCountFromCoords($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
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
	
	return $self->_getDataCountFromCollection(PRIMARY_COLLECTION,$rangeData);
}

use constant {
	DLAT_CONCEPT_DOMAIN_NAME	=>	'dlat',
	EXPG_CONCEPT_DOMAIN_NAME	=>	'exp',
	EXPT_CONCEPT_DOMAIN_NAME	=>	'exp',
	RREG_CONCEPT_DOMAIN_NAME	=>	'rreg',
	PDNA_CONCEPT_DOMAIN_NAME	=>	'pdna',
	
	DLAT_CONCEPT_NAME	=>	'mr',
	EXPG_CONCEPT_NAME	=>	'g',
	EXPT_CONCEPT_NAME	=>	't',
	RREG_CONCEPT_NAME	=>	'p',
	PDNA_CONCEPT_NAME	=>	'p',
	
	DLAT_AGG_NAME	=>	'Wgbs',
	EXPG_AGG_NAME	=>	'RnaSeqG',
	EXPT_AGG_NAME	=>	'RnaSeqT',
	RREG_AGG_NAME	=>	'Dnase',
	PDNA_AGG_NAME	=>	'ChipSeq',
};

sub _getDataStatsFromCollection($$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($collectionName,$rangeData) = @_;
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'collections'}{$collectionName})) {
		my $collection = $model->getCollection($collectionName);
		
		if(defined($collection)) {
			my $shouldQuery = $self->_genShouldQuery($rangeData);
			my $key_name = $collection2id{$collectionName};
			
			my $DLAT_CONCEPT = $model->getConceptDomain(DLAT_CONCEPT_DOMAIN_NAME)->conceptHash()->{DLAT_CONCEPT_NAME()}->id();
			my $EXPG_CONCEPT = $model->getConceptDomain(EXPG_CONCEPT_DOMAIN_NAME)->conceptHash()->{EXPG_CONCEPT_NAME()}->id();
			my $EXPT_CONCEPT = $model->getConceptDomain(EXPT_CONCEPT_DOMAIN_NAME)->conceptHash()->{EXPT_CONCEPT_NAME()}->id();
			my $RREG_CONCEPT = $model->getConceptDomain(RREG_CONCEPT_DOMAIN_NAME)->conceptHash()->{RREG_CONCEPT_NAME()}->id();
			my $PDNA_CONCEPT = $model->getConceptDomain(PDNA_CONCEPT_DOMAIN_NAME)->conceptHash()->{PDNA_CONCEPT_NAME()}->id();
			
			my %agg2type = (
				DLAT_AGG_NAME()	=>	$DLAT_CONCEPT,
				EXPG_AGG_NAME()	=>	$EXPG_CONCEPT,
				EXPT_AGG_NAME()	=>	$EXPT_CONCEPT,
				RREG_AGG_NAME()	=>	$RREG_CONCEPT,
				PDNA_AGG_NAME()	=>	$PDNA_CONCEPT,
			);
			
			my $query_body = {
				'query'	=>	{
					'filtered'	=>	{
						'filter'	=>	{
							'bool'	=>	{
								'should'	=>	$shouldQuery
							}
						}
					}
				},
				'aggregations'	=>	{
					DLAT_AGG_NAME()	=>	{
						'filter'	=>	{
							'term'	=>	{
								'_type'	=>	$DLAT_CONCEPT
							}
						},
						'aggregations'	=>	{
							'analyses'	=>	{
								'terms'	=>	{
									'field'	=>	$key_name,
									'size'	=>	0
								},
								'aggs'	=>	{
									'stats_meth_level'	=>	{
										'extended_stats'	=>	{
											'field'	=>	'meth_level'
										}
									}
								}
							}
						}
					},
					EXPG_AGG_NAME()	=>	{
						'filter'	=>	{
							'term'	=>	{
								'_type'	=>	$EXPG_CONCEPT
							}
						},
						'aggregations'	=>	{
							'analyses'	=>	{
								'terms'	=>	{
									'field'	=>	$key_name,
									'size'	=>	0
								},
								'aggs'	=>	{
									'stats_normalized_read_count'	=>	{
										'extended_stats'	=>	{
											'field'	=>	'expected_count'
										}
									}
								}
							}
						}
					},
					EXPT_AGG_NAME()	=>	{
						'filter'	=>	{
							'term'	=>	{
								'_type'	=>	$EXPT_CONCEPT
							}
						},
						'aggregations'	=>	{
							'analyses'	=>	{
								'terms'	=>	{
									'field'	=>	$key_name,
									'size'	=>	0
								},
								'aggs'	=>	{
									'stats_normalized_read_count'	=>	{
										'extended_stats'	=>	{
											'field'	=>	'expected_count'
										}
									}
								}
							}
						}
					},
					RREG_AGG_NAME()	=>	{
						'filter'	=>	{
							'term'	=>	{
								'_type'	=>	$RREG_CONCEPT
							}
						},
						'aggregations'	=>	{
							'analyses'	=>	{
								'terms'	=>	{
									'field'	=>	$key_name,
									'size'	=>	0
								},
								'aggs'	=>	{
									'peak_size'	=>	{
										'sum'	=>	{
											'lang'	=>	"expression",
											'script'	=>	"doc['chromosome_end'].value - doc['chromosome_start'].value + 1" 
										}
									}
								}
							}
						}
					},
					PDNA_AGG_NAME()	=>	{
						'filter'	=>	{
							'term'	=>	{
								'_type'	=>	$PDNA_CONCEPT
							}
						},
						'aggregations'	=>	{
							'analyses'	=>	{
								'terms'	=>	{
									'field'	=>	$key_name,
									'size'	=>	0
								},
								'aggs'	=>	{
									'peak_size'	=>	{
										'sum'	=>	{
											'lang'	=>	"expression",
											'script'	=>	"doc['chromosome_end'].value - doc['chromosome_start'].value + 1" 
										}
									}
								}
							}
						}
					}
				}
			};
			
			my $mapper = $self->{mapper};
			
			my $results = $mapper->immediateQueryCollection($collection,$query_body,'count',undef,{'request_cache' => boolean::true });
			
			if(exists($results->{'aggregations'})) {
				my @dataArr = ();
				foreach my $aggType (keys(%agg2type)) {
					my $type = $agg2type{$aggType};
					
					foreach my $data (@{$results->{'aggregations'}->{$aggType}->{'analyses'}->{'buckets'}}) {
						$data->{_type} = $type;
						push(@dataArr,$data);
					}
				}
				$retval = \@dataArr;
			}
		}
	}
	
	return $retval;
}

sub getDataStatsFromCoords($$$) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
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
	
	return $self->_getDataStatsFromCollection(PRIMARY_COLLECTION,$rangeData);
}

sub getGenomicLayout($) {
	my $self = shift;
	
	Carp::croak((caller(0))[3].' is an instance method!')  if(BP::Model::DEBUG && !ref($self));
	
	my($rangeData) = @_;
	
	my $conceptDomainName = EXTERNAL_COLLECTION();
	my $conceptName = FEATURES_CONCEPT();
	my $prefix = 'coordinates';
	
	my $model = $self->{model};
	my $dbModel = $self->getModelFromDomain();
	my $retval = undef;
	if(exists($dbModel->{'domains'}{$conceptDomainName})) {
		my $conceptDomain = $model->getConceptDomain($conceptDomainName);
		
		if(defined($conceptDomain) && exists($conceptDomain->conceptHash()->{$conceptName})) {
			my $concept = $conceptDomain->conceptHash()->{$conceptName};
			my $nestedShouldQuery = $self->_genShouldQuery($rangeData,$prefix);
			my $query_body = {
				'query'	=>	{
					'filtered'	=>	{
						'filter'	=>	{
							'bool'	=>	{
								'must'	=>	[
									{
										'terms'	=>	{
											'feature'	=>	REGION_FEATURES()
										}
									},
									$nestedShouldQuery
								]
							}
						}
					}
				}
			};
			
			my $mapper = $self->{mapper};
			
			my $scroll = $mapper->queryConcept($concept,$query_body);
			
			my @dataArr = ();
			until($scroll->is_finished) {
				$scroll->refill_buffer();
				my @docs = $scroll->drain_buffer();
				
				if(scalar(@docs) > 0) {
					$retval = \@dataArr;
					foreach my $doc (@docs) {
						my $data = $doc->{_source};
						$data->{_type} = $doc->{_type};
						
						push(@dataArr,$data);
					}
				}
			}
		}
	}
	
	return $retval;
}

1;
