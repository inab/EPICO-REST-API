#!/usr/bin/perl
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jose.m.fernandez@bsc.es)

use strict;
use warnings 'all';

use boolean qw();

use EPICO::REST::Common;

package EPICO::REST::API;

use Dancer2;
#use Dancer2::Serializer::JSON;
use Dancer2::Serializer::MaybeJSON;
use Dancer2::Session::YAML;

set engines => {
	'serializer' => {
		'MaybeJSON' => {
			'convert_blessed' => 1,
			'utf8'	=>	1,
#			'pretty'	=>	1,
		},
		'JSON' => {
			'convert_blessed' => 1,
			'utf8'	=>	1,
#			'pretty'	=>	1,
		}
	},
	'deserializer' => {
		'MaybeJSON' => {
			'utf8'	=>	0
		},
		'JSON' => {
			'utf8'	=>	0
		}
	},
	'session' => {
		'YAML' => {
			'session_dir' => '/tmp/dancer-epico-sessions'
		}
	}
};
set session => 'YAML';
#set serializer => 'JSON';
set serializer => 'MaybeJSON';

set charset => 'UTF-8';

###############
# List domains
#############

sub getDomainInternal($\@) {
	my($domain_id,$p_domain) = @_;
	
	return {
		'domain_id'	=>	$domain_id,
		'domain_name'	=>	$p_domain->[EPICO::REST::Common::DOMAIN_NAME],
		'release'	=>	$p_domain->[EPICO::REST::Common::RELEASE],
		'is_instantiated'	=>	defined($p_domain->[EPICO::REST::Common::DOMAIN_INSTANCE]) ? boolean::true : boolean::false,
	};
}

sub listDomains() {
	my $p_domains = EPICO::REST::Common::loadDomains();
	
	my @domains = ();
	
	foreach my $domain_id (keys(%{$p_domains})) {
		my $p_domain = $p_domains->{$domain_id};
		my $domainJson = getDomainInternal($domain_id,@{$p_domain});
		
		push(@domains,$domainJson);
	}
	
	return \@domains;
}

get '/'	=>	\&listDomains;

sub getDomain() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	my $p_domain = undef;
	if(defined($domainInstance)) {
		my $p_domains = EPICO::REST::Common::loadDomains();
		$p_domain = $p_domains->{$domain_id};
	} else {
		send_error("Domain $domain_id not found",404);
	}
	
	return getDomainInternal($domain_id,@{$p_domain});
}

sub getModel() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getModelFromDomain();
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getAvailableCVs() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getAvailableCVs();
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getCV() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $cv_id = params->{'cv_id'};
		my $cvmeta = $domainInstance->getCV($cv_id);
		
		send_error("CV $cv_id in domain $domain_id not found",404)  unless(defined($cvmeta));
		return $cvmeta;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getCVterms() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	
	my $p_theUris = undef;
	
	if(request->method() eq 'POST') {
		$p_theUris = request->data;
		send_error("Expected an input array of strings",400)  unless(ref($p_theUris) eq 'ARRAY');
		foreach my $term (@{$p_theUris}) {
			send_error("Expected an input array of strings (an element is not a string)",400)  unless(defined($term) && ref($term) eq '');
		}
	}
	
	
	if(defined($domainInstance)) {
		my $cv_id = params->{'cv_id'};
		my $comma = index($cv_id,',');
		my $p_cv_ids;
		if($comma!=-1) {
			my @cv_ids = split(/,/,$cv_id);
			
			$p_cv_ids = \@cv_ids;
		} else {
			$p_cv_ids = $cv_id;
		}
		my $cvTerms = $domainInstance->getCVterms($p_cv_ids,$p_theUris);
		
		send_error("CV $cv_id in domain $domain_id not found",404)  unless(defined($cvTerms));
		return $cvTerms;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getFilteredCVterms() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $p_theTerms = request->data;
		
		send_error("Expected an input array of strings",400)  unless(ref($p_theTerms) eq 'ARRAY');
		foreach my $term (@{$p_theTerms}) {
			send_error("Expected an input array of strings (an element is not a string)",400)  unless(defined($term) && ref($term) eq '');
		}
		
		my $cvTerms = $domainInstance->getFilteredCVterms($p_theTerms);
		
		send_error("Filtered CV terms in domain $domain_id not found",404)  unless(defined($cvTerms));
		
		return $cvTerms;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getCVsFromColumn() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $retval = $domainInstance->getCVsFromColumn(params->{'conceptDomainName'},params->{'conceptName'},params->{'columnName'});
		send_error("Concept domain ".params->{'conceptDomainName'}.", concept ".params->{'conceptName'}.", column ".params->{'columnName'}." not found on $domain_id",404)  unless(defined($retval));
		return $retval;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getCVtermsFromColumn() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $p_theUris = undef;
		$p_theUris = request->data  if(request->method() eq 'POST');
		
		my $retval = $domainInstance->getCVtermsFromColumn(params->{'conceptDomainName'},params->{'conceptName'},params->{'columnName'},$p_theUris);
		send_error("Concept domain ".params->{'conceptDomainName'}.", concept ".params->{'conceptName'}.", column ".params->{'columnName'}." not found on $domain_id",404)  unless(defined($retval));
		return $retval;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getSampleTrackingDataIds() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSampleTrackingData(1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getSampleTrackingData() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSampleTrackingData();
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getDonors() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDonors(undef,1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getDonor() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDonors(params->{'donor_id'});
	} else {
		send_error("Donor ".params->{'donor_id'}." in domain $domain_id not found",404);
	}
}

sub getSpecimens() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSpecimens(undef,1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getSpecimen() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSpecimens(params->{'specimen_id'});
	} else {
		send_error("Specimen ".params->{'specimen_id'}." in domain $domain_id not found",404);
	}
}

sub getSamples() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSamples(undef,1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getSample() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getSamples(params->{'sample_id'});
	} else {
		send_error("Sample ".params->{'sample_id'}." in domain $domain_id not found",404);
	}
}

sub getExperiments() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getExperiments(undef,1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getExperiment() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getExperiments(params->{'experiment_id'});
	} else {
		send_error("Experiment ".params->{'experiment_id'}." in domain $domain_id not found",404);
	}
}

sub getAnalysisMetadatas() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getAnalysisMetadata(undef,1);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getAnalysisMetadata() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getAnalysisMetadata(params->{'analysis_id'});
	} else {
		send_error("Analysis metadata ".params->{'analysis_id'}." in domain $domain_id not found",404);
	}
}

sub getDataFromCoordsCommon(@) {
	my($domain_id, $chromosome,$chromosome_start,$chromosome_end) = @_;
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDataFromCoords($chromosome,$chromosome_start,$chromosome_end);
	} else {
		send_error("Data on coordinates ".$chromosome.':'.$chromosome_start.'-'.$chromosome_end." in domain $domain_id not found",404);
	}
}

sub getDataFromCoords() {
	return getDataFromCoordsCommon((params->{'domain_id'},params->{'chromosome'},params->{'chromosome_start'},params->{'chromosome_end'}));
}


sub getDataFromCoordsAlt() {
	return getDataFromCoordsCommon(splat);
}

sub getDataStreamFromCoordsCommon(@) {
	my($domain_id, $chromosome,$chromosome_start,$chromosome_end) = @_;
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDataStreamFromCoords($chromosome,$chromosome_start,$chromosome_end);
	} else {
		send_error("Data on coordinates ".$chromosome.':'.$chromosome_start.'-'.$chromosome_end." in domain $domain_id not found",404);
	}
}

sub getDataStreamFromCoords() {
	return getDataStreamFromCoordsCommon((params->{'domain_id'},params->{'chromosome'},params->{'chromosome_start'},params->{'chromosome_end'}));
}


sub getDataStreamFromCoordsAlt() {
	return getDataStreamFromCoordsCommon(splat);
}

sub fetchDataStream() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $p_scroll = request->data;
		
		send_error("Expected a hash defining the stream",400)  unless(ref($p_scroll) eq 'HASH');
		
		my $retval = $domainInstance->fetchDataStream($p_scroll);
		
		send_error("Stream already closed or not found",404)  unless(defined($retval));
		
		return $retval;
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getDataCountFromCoordsCommon(@) {
	my($domain_id, $chromosome,$chromosome_start,$chromosome_end) = @_;
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDataCountFromCoords($chromosome,$chromosome_start,$chromosome_end);
	} else {
		send_error("Data count on coordinates ".$chromosome.':'.$chromosome_start.'-'.$chromosome_end." in domain $domain_id not found",404);
	}
}

sub getDataCountFromCoords() {
	return getDataCountFromCoordsCommon((params->{'domain_id'},params->{'chromosome'},params->{'chromosome_start'},params->{'chromosome_end'}));
}


sub getDataCountFromCoordsAlt() {
	return getDataCountFromCoordsCommon(splat);
}

sub getDataStatsFromCoordsCommon(@) {
	my($domain_id, $chromosome,$chromosome_start,$chromosome_end) = @_;
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getDataStatsFromCoords($chromosome,$chromosome_start,$chromosome_end);
	} else {
		send_error("Data stats on coordinates ".$chromosome.':'.$chromosome_start.'-'.$chromosome_end." in domain $domain_id not found",404);
	}
}

sub getDataStatsFromCoords() {
	return getDataStatsFromCoordsCommon((params->{'domain_id'},params->{'chromosome'},params->{'chromosome_start'},params->{'chromosome_end'}));
}


sub getDataStatsFromCoordsAlt() {
	return getDataStatsFromCoordsCommon(splat);
}

sub getGenomicLayoutFromCoordsCommon(@) {
	my($domain_id, $chromosome,$chromosome_start,$chromosome_end) = @_;
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		return $domainInstance->getGenomicLayoutFromCoords($chromosome,$chromosome_start,$chromosome_end);
	} else {
		send_error("Genomic layout on coordinates ".$chromosome.':'.$chromosome_start.'-'.$chromosome_end." in domain $domain_id not found",404);
	}
}

sub getGenomicLayoutFromCoords() {
	return getGenomicLayoutFromCoordsCommon((params->{'domain_id'},params->{'chromosome'},params->{'chromosome_start'},params->{'chromosome_end'}));
}


sub getGenomicLayoutFromCoordsAlt() {
	return getGenomicLayoutFromCoordsCommon(splat);
}

sub queryFeatures() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $queryString = exists(query_parameters->{'q'}) ? query_parameters->{'q'} : undef;
		
		if(defined($queryString)) {
			$queryString =~ s/^\s+//;
			$queryString =~ s/\s+$//;
			$queryString = undef  if(length($queryString) == 0);
		}
		
		send_error("Empty query",400)  unless(defined($queryString));
		return $domainInstance->queryFeatures($queryString);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub suggestFeatures() {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $queryString = exists(query_parameters->{'q'}) ? query_parameters->{'q'} : undef;
		
		if(defined($queryString)) {
			$queryString =~ s/^\s+//;
			$queryString =~ s/\s+$//;
			$queryString = undef  if(length($queryString) == 0);
		}
		
		send_error("Empty query",400)  unless(defined($queryString));
		return $domainInstance->suggestFeatures($queryString);
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub preflight {
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	return undef;
}

# It takes as input a string, splitting it by lines, cleaning them up, and returning them as "compound ids"
sub _inputDeserialize($) {
	my($input) = @_;
	
	my @lines = map { my $a = $_ ; $a =~ s/^[ \t]+//; $a =~ s/[ \t]+$//; [ $a ] } split(/[\r\n]+/,$input);
	
	return \@lines;
}

sub _rregSerialize($\@) {
	my($headerName,$p_data) = @_;
	
	my @partialColumns = ('chromosome','chromosome_start','chromosome_end','z_score');
	my $res = join("\t",'# '.$headerName,@partialColumns)."\n";
	
	foreach my $p_analysis (@{$p_data}) {
		my $analysis_id = join(':',@{$p_analysis->{'id'}});
		
		my $lines = join("\n", map { join("\t",$analysis_id,$_->[0],$_->[1],$_->[2],$->[3]) } @{$p_analysis->{'data'}});
		
		$res .= $lines ."\n";
	}
	
	return $res;
}

# It expects a header name and an array of hashes
# Each hash contains two keys: 'id' and 'data'
# 'id' is a reference to an array of identifiers for the data
# 'data' is a reference to a matrix (an array of arrays), of three columns
# First column is the Ensembl gene id
# Second column is the gene name
# Third column is the expression value for the gene
sub _tabSerialize($\@) {
	my($headerName,$p_data) = @_;
	
	my @partialColumns = ('gene_id','gene_name','FPKM');
	my $res = join("\t",'# '.$headerName,@partialColumns)."\n";
	
	foreach my $p_analysis (@{$p_data}) {
		my $analysis_id = join(':',@{$p_analysis->{'id'}});
		
		my $lines = join("\n", map { join("\t",$analysis_id,$_->[0],$_->[1],$_->[2]) } @{$p_analysis->{'data'}});
		
		$res .= $lines ."\n";
	}
	
	return $res;
}

# It expects a header name and an array of hashes
# Each hash contains two keys: 'id' and 'data'
# 'id' is a reference to an array of identifiers for the data
# 'data' is a reference to a matrix (an array of arrays), of three columns
# First column is the Ensembl gene id
# Second column is the gene name
# Third column is the expression value for the gene
sub _matrixSerialize($\@) {
	my($headerName,$p_data) = @_;
	
	# First pass, cluster the gene expressions
	my $iAnal = 0;
	my %geneIds = ();
	foreach my $p_analysis (@{$p_data}) {
		foreach my $p_geneExpr (@{$p_analysis->{'data'}}) {
			my $gene_id = $p_geneExpr->[0];
			
			$geneIds{$gene_id} = {'gene_id' => $gene_id,'gene_name' => $p_geneExpr->[1], 'expr' => []}  unless(exists($geneIds{$gene_id}));
			my $p_geneExprArr = $geneIds{$gene_id}{'expr'};
			
			# We save only the FPKM
			if(scalar(@{$p_geneExprArr}) > 0 && $p_geneExprArr->[-1][0] eq $iAnal) {
				push(@{$p_geneExprArr->[-1][1]},$p_geneExpr->[2]);
			} else {
				push(@{$p_geneExprArr},[$iAnal,[$p_geneExpr->[2]]]);
			}
		}
		
		$iAnal++;
	}
	
	# Second pass, sort by gene name
	my @sortedGeneExprInstances = sort { $a->{'gene_name'} cmp $b->{'gene_name'} } values(%geneIds);
	my $res = join("\t",'# gene_name','gene_id',map { join(':',@{$_->{'id'}}) } @{$p_data})."\n";
	# Number of analysis
	my $maxAnalIdx = scalar(@{$p_data});
	
	foreach my $p_geneExprInstance (@sortedGeneExprInstances) {
		# First, the gene name and id
		$res .= join("\t",$p_geneExprInstance->{'gene_name'},$p_geneExprInstance->{'gene_id'});
		
		# As we are storing a sparse matrix, we have to take care of the holes
		my $nextAnalIdx = 0;
		foreach my $p_GeneExprElem (@{$p_geneExprInstance->{'expr'}}) {
			my($iAnalIdx,$p_FPKM) = @{$p_GeneExprElem};
			
			$res .= "\tNA" x ($iAnalIdx - $nextAnalIdx)  if($nextAnalIdx != $iAnalIdx);
			
			$res .= "\t" . join(",",@{$p_FPKM});
			
			$nextAnalIdx = $iAnalIdx + 1;
		}
		
		# Corner case
		$res .= "\tNA" x ($maxAnalIdx - $nextAnalIdx)  if($nextAnalIdx != $maxAnalIdx);
		$res .= "\n";
	}
	
	return $res;
}

sub _tabSerializeGenerator($) {
	my($idColumnName) = @_;
	
	return sub(\@) {
		my($p_res) = @_;
		
		my $tablines = '';
		if(defined($idColumnName)) {
			my @partialColumns = ('gene_id','gene_name','FPKM');
			$tablines .= join("\t",'# '.$idColumnName,@partialColumns)."\n";
			
			# Only do this once!
			$idColumnName = undef;
		}
		
		foreach my $res (@{$p_res}) {
			my $analysis_id = join(':',@{$res->{'compound_analysis_id'}});
				
			$tablines .= join("\t",$analysis_id,$res->{'gene_stable_id'},$res->{'gene_stable_name'},$res->{'FPKM'})."\n";
		}
		
		content $tablines;
		
		return undef;
	};
}

sub _rregSerializeGenerator($) {
	my($idColumnName) = @_;
	
	return sub(\@) {
		my($p_res) = @_;
		
		my $tablines = '';
		if(defined($idColumnName)) {
			my @partialColumns = ('chromosome','chromosome_start','chromosome_end','z_score');
			$tablines .= join("\t",'# '.$idColumnName,@partialColumns)."\n";
			
			# Only do this once!
			$idColumnName = undef;
		}
		
		foreach my $res (@{$p_res}) {
			my $analysis_id = join(':',@{$res->{'compound_analysis_id'}});
				
			$tablines .= join("\t",$analysis_id,$res->{'chromosome'},$res->{'chromosome_start'},$res->{'chromosome_end'},$res->{'z_score'})."\n";
		}
		
		content $tablines;
		
		return undef;
	};
}


sub _getQueryByAnalysesCommon($$$) {
	my($p_dataMethod,$queryMethodName,$p_serializeGeneratorMethod) = @_;
	
	my($id_attr,$dataMethodName,$p_experimentFilterMethod) = @{$p_dataMethod};
	
	my $domain_id = params->{'domain_id'};
	my $domainInstance = undef;
	
	eval {
		$domainInstance = EPICO::REST::Common::getDomain($domain_id);
	};
	
	if($@) {
		send_error("Domain $domain_id could not be instantiated",500);
		print STDERR "ERROR: $@\n";
	}
	
	if(defined($domainInstance)) {
		my $content = request->method() eq 'POST' ? request->body : params->{$id_attr};
		
		# Cleaning up the input
		my $p_deserialized_ids = _inputDeserialize($content);
		
		my($idColumnName,$p_compound_analysis_ids) = $domainInstance->$dataMethodName($p_deserialized_ids,$p_experimentFilterMethod);
		
		if(scalar(@{$p_compound_analysis_ids}) > 0) {
			delayed {
				content_type 'text/tab-separated-values; charset=UTF-8';
				
				flush;
				
				my $p_tabSerializeOnce = $p_serializeGeneratorMethod->($idColumnName);
				
				$domainInstance->$queryMethodName($p_compound_analysis_ids,$p_tabSerializeOnce);
				
				done;
			};
		} else {
			send_error("No matching experiment for input ids",404);
		}
	} else {
		send_error("Domain $domain_id not found",404);
	}
}

sub getGeneExpressionByAnalysesTab {
	return _getQueryByAnalysesCommon(['analysis_id','getCompoundAnalysisIdsFromCompoundAnalysisIds',\&EPICO::REST::Backend::_FilterEntryByExpressionAnalysisMetadata],'getGeneExpressionFromCompoundAnalysisIds',\&_tabSerializeGenerator);
}

sub getGeneExpressionByExperimentsTab {
	return _getQueryByAnalysesCommon(['expression_id','getCompoundAnalysisIdsFromCompoundExperimentIds',\&EPICO::REST::Backend::_FilterEntryByExpressionAnalysisMetadata],'getGeneExpressionFromCompoundAnalysisIds',\&_tabSerializeGenerator);
}

sub getGeneExpressionBySamplesTab {
	return _getQueryByAnalysesCommon(['sample_id','getCompoundAnalysisIdsFromCompoundSampleIds',\&EPICO::REST::Backend::_FilterEntryByExpressionAnalysisMetadata],'getGeneExpressionFromCompoundAnalysisIds',\&_tabSerializeGenerator);
}

sub getGeneExpressionByDonorsTab {
	return _getQueryByAnalysesCommon(['donor_id','getCompoundAnalysisIdsFromCompoundDonorIds',\&EPICO::REST::Backend::_FilterEntryByExpressionAnalysisMetadata],'getGeneExpressionFromCompoundAnalysisIds',\&_tabSerializeGenerator);
}



sub getRegulatoryRegionsByAnalysesTab {
	return _getQueryByAnalysesCommon(['analysis_id','getCompoundAnalysisIdsFromCompoundAnalysisIds',\&EPICO::REST::Backend::_FilterEntryByRegulatoryRegionsMetadata],'getRegulatoryRegionsFromCompoundAnalysisIds',\&_rregSerializeGenerator);
}

sub getRegulatoryRegionsByExperimentsTab {
	return _getQueryByAnalysesCommon(['experiment_id','getCompoundAnalysisIdsFromCompoundExperimentIds',\&EPICO::REST::Backend::_FilterEntryByRegulatoryRegionsMetadata],'getRegulatoryRegionsFromCompoundAnalysisIds',\&_rregSerializeGenerator);
}

sub getRegulatoryRegionsBySamplesTab {
	return _getQueryByAnalysesCommon(['sample_id','getCompoundAnalysisIdsFromCompoundSampleIds',\&EPICO::REST::Backend::_FilterEntryByRegulatoryRegionsMetadata],'getRegulatoryRegionsFromCompoundAnalysisIds',\&_rregSerializeGenerator);
}

sub getRegulatoryRegionsByDonorsTab {
	return _getQueryByAnalysesCommon(['donor_id','getCompoundAnalysisIdsFromCompoundDonorIds',\&EPICO::REST::Backend::_FilterEntryByRegulatoryRegionsMetadata],'getRegulatoryRegionsFromCompoundAnalysisIds',\&_rregSerializeGenerator);
}



prefix '/:domain_id' => sub {
	get ''	=>	\&getDomain;
	get '/model'	=>	\&getModel;
	prefix '/model/CV' => sub {
		get ''	=>	\&getAvailableCVs;
		post '/terms'	=>	\&getFilteredCVterms;
		options '/terms'	=>	\&preflight;
		get '/:cv_id'	=>	\&getCV;
		get '/:cv_id/terms'	=>	\&getCVterms;
		post '/:cv_id/terms'	=>	\&getCVterms;
		options '/:cv_id/terms'	=>	\&preflight;
		get '/:conceptDomainName/:conceptName/:columnName'	=>	\&getCVsFromColumn;
		get '/:conceptDomainName/:conceptName/:columnName/terms'	=>	\&getCVtermsFromColumn;
		post '/:conceptDomainName/:conceptName/:columnName/terms'	=>	\&getCVtermsFromColumn;
		options '/:conceptDomainName/:conceptName/:columnName/terms'	=>	\&preflight;
	};
	prefix '/sdata' => sub {
		get ''	=>	\&getSampleTrackingDataIds;
		get '/_all'	=>	\&getSampleTrackingData;
		get '/donor'	=>	\&getDonors;
		get '/donor/:donor_id'	=>	\&getDonor;
		get '/specimen'	=>	\&getSpecimens;
		get '/specimen/:specimen_id'	=>	\&getSpecimen;
		get '/sample'	=>	\&getSamples;
		get '/sample/:sample_id'	=>	\&getSample;
		get '/experiment'	=>	\&getExperiments;
		get '/experiment/:experiment_id'	=>	\&getExperiment;
	};
	prefix '/analysis/metadata' => sub {
		get ''	=>	\&getAnalysisMetadatas;
		get '/:analysis_id'	=>	\&getAnalysisMetadata;
	};
	prefix '/analysis/data' => sub {
		get '/:chromosome/:chromosome_start/:chromosome_end'	=>	\&getDataFromCoords;
		# As Dancer2 fails on this, we have to setup a full route for it
		# get qr{/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)}	=>	\&getDataFromCoordsAlt;
		get '/:chromosome/:chromosome_start/:chromosome_end/stats'	=>	\&getDataStatsFromCoords;
		# As Dancer2 fails on this, we have to setup a full route for it
		# get qr{/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)/stats}	=>	\&getDataStatsFromCoordsAlt;
		get '/:chromosome/:chromosome_start/:chromosome_end/count'	=>	\&getDataCountFromCoords;
		# As Dancer2 fails on this, we have to setup a full route for it
		# get qr{/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)/count}	=>	\&getDataCountFromCoordsAlt;
		get '/:chromosome/:chromosome_start/:chromosome_end/stream'	=>	\&getDataStreamFromCoords;
		# As Dancer2 fails on this, we have to setup a full route for it
		# get qr{/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)}	=>	\&getDataStreamFromCoordsAlt;
		post '/fetchStream'	=>	\&fetchDataStream;
		options '/fetchStream'	=>	\&preflight;
	};
	prefix '/analysis/query/gene_expression' => sub {
		prefix '/byDonors' => sub {
			post ''	=>	\&getGeneExpressionByDonorsTab;
			options ''	=>	\&preflight;
			get '/:donor_id'	=>	\&getGeneExpressionByDonorsTab;
		};
		prefix '/bySamples' => sub {
			post ''	=>	\&getGeneExpressionBySamplesTab;
			options ''	=>	\&preflight;
			get '/:sample_id'	=>	\&getGeneExpressionBySamplesTab;
		};
		prefix '/byExperiments' => sub {
			post ''	=>	\&getGeneExpressionByExperimentsTab;
			options ''	=>	\&preflight;
			get '/:experiment_id'	=>	\&getGeneExpressionByExperimentsTab;
		};
		prefix '/byAnalyses' => sub {
			post ''	=>	\&getGeneExpressionByAnalysesTab;
			options ''	=>	\&preflight;
			get '/:analysis_id'	=>	\&getGeneExpressionByAnalysesTab;
		};
	};
	prefix '/analysis/query/regulatory_regions' => sub {
		prefix '/byDonors' => sub {
			post ''	=>	\&getRegulatoryRegionsByDonorsTab;
			options ''	=>	\&preflight;
			get '/:donor_id'	=>	\&getRegulatoryRegionsByDonorsTab;
		};
		prefix '/bySamples' => sub {
			post ''	=>	\&getRegulatoryRegionsBySamplesTab;
			options ''	=>	\&preflight;
			get '/:sample_id'	=>	\&getRegulatoryRegionsBySamplesTab;
		};
		prefix '/byExperiments' => sub {
			post ''	=>	\&getRegulatoryRegionsByExperimentsTab;
			options ''	=>	\&preflight;
			get '/:experiment_id'	=>	\&getRegulatoryRegionsByExperimentsTab;
		};
		prefix '/byAnalyses' => sub {
			post ''	=>	\&getRegulatoryRegionsByAnalysesTab;
			options ''	=>	\&preflight;
			get '/:analysis_id'	=>	\&getRegulatoryRegionsByAnalysesTab;
		};
	};
	prefix '/genomic_layout' => sub {
		get '/:chromosome/:chromosome_start/:chromosome_end'	=>	\&getGenomicLayoutFromCoords;
		# As Dancer2 fails on this, we have to setup a full route for it
		# get qr{/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)}	=>	\&getGenomicLayoutFromCoordsAlt;
	};
	get '/features' => \&queryFeatures;
	get '/features/suggest' => \&suggestFeatures;
};
get qr{/([^/]+)/analysis/data/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)/count}	=>	\&getDataCountFromCoordsAlt;
get qr{/([^/]+)/analysis/data/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)/stats}	=>	\&getDataStatsFromCoordsAlt;
get qr{/([^/]+)/analysis/data/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)/stream}	=>	\&getDataStreamFromCoordsAlt;
get qr{/([^/]+)/analysis/data/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)}	=>	\&getDataFromCoordsAlt;
get qr{/([^/]+)/genomic_layout/([^:]+):([1-9][0-9]*)-([1-9][0-9]*)}	=>	\&getGenomicLayoutFromCoordsAlt;

1;