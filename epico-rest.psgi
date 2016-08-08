#!/usr/bin/perl
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jmfernandez@cnio.es)

use strict;
use warnings 'all';

use boolean qw();
use File::Spec;
use File::Temp qw();
use JSON -no_export;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin,"libs");
use lib File::Spec->catfile($FindBin::Bin,"BP-Schema-tools","lib");

package EPICO::REST::Common;

use constant RELATIVE_CONFIG_DIR	=>	'config';
use constant CONFIG_DIR	=>	File::Spec->catdir($FindBin::Bin,RELATIVE_CONFIG_DIR);

my %backendMap = (
	'EPICO'	=>	'EPICO::REST::Backend::EPICO'
);

use constant {
	DOMAIN_INSTANCE	=>	0,
	BACKEND	=>	1,
	BACKEND_CFG	=>	2,
	BACKEND_INICFG	=>	3,
	DOMAIN_ID	=>	4,
	DOMAIN_NAME	=>	5,
	RELEASE	=>	6,
};

{
	use Config::IniFiles;
	use constant EPICO_API_SECTION	=>	'epico-api';
	use constant {
		NAME_PARAMETER	=>	'name',
		RELEASE_PARAMETER	=>	'release',
		BACKEND_PARAMETER	=>	'backend',
	};
	
	my %domains = ();
	# In epoch time
	my $lastLoadedDomains = undef;
	
	sub loadDomains() {
		unless(defined($lastLoadedDomains)) {
			if(opendir(my $CONFDIR,CONFIG_DIR)) {
				%domains = ();
				while(my $entryName = readdir($CONFDIR)) {
					if($entryName =~ /\.ini$/) {
						my $fullEntryName = File::Spec->catfile(CONFIG_DIR,$entryName);
						if(-f $fullEntryName && -r $fullEntryName) {
							my $cfg = Config::IniFiles->new( -file => $fullEntryName);
							
							if($cfg->SectionExists(EPICO_API_SECTION) && $cfg->exists(EPICO_API_SECTION,NAME_PARAMETER) && $cfg->exists(EPICO_API_SECTION,RELEASE_PARAMETER) && $cfg->exists(EPICO_API_SECTION,BACKEND_PARAMETER)) {
								my $domainName = $cfg->val(EPICO_API_SECTION,NAME_PARAMETER);
								my $release = $cfg->val(EPICO_API_SECTION,RELEASE_PARAMETER);
								my $backendName = $cfg->val(EPICO_API_SECTION,BACKEND_PARAMETER);
								
								if(exists($backendMap{$backendName})) {
									my $domain_id = $backendName.':'.$release;
									$domains{$domain_id} = [undef,$backendMap{$backendName},$cfg,$fullEntryName,$domain_id,$domainName,$release];
								} else {
									print STDERR "ERROR: Unknown domain name $domainName from file $fullEntryName\n";
								}
							} else {
								print STDERR "ERROR: File $fullEntryName does not contain the needed section or entries. Ignoring...\n";
							}
						} else {
							print STDERR "ERROR: File $fullEntryName is not readable or a file. Ignoring...\n";
						}
					}
				}
				closedir($CONFDIR);
				
				$lastLoadedDomains = time();
			} else {
				print STDERR "ERROR: Unable to open configurations directory ".CONFIG_DIR."\n";
			}
		}
		
		return defined($lastLoadedDomains) ? \%domains : undef;
	}
	
	sub reloadDomains() {
		$lastLoadedDomains = undef;
		loadDomains();
	}
	
	sub getLastLoadedDomainsTime() {
		return $lastLoadedDomains;
	}
	
	# Obtaining an specific, instantiated, domain
	sub getDomain($) {
		my($domainName) = @_;
		
		my $domainInstance = undef;
		my $p_domains = loadDomains();
		
		if(defined($p_domains)) {
			if(exists($p_domains->{$domainName})) {
				my $p_domain = $p_domains->{$domainName};
				
				unless(defined($p_domain->[DOMAIN_INSTANCE])) {
					# Creating a new instance, passing the Config::IniFile instance as parameter
					eval "require " . $p_domain->[BACKEND];
					
					if($@) {
						print STDERR "ERROR REQ: $@\n";
						Carp::croak($p_domain->[BACKEND] . " could not be required. Reason: $@");
					}
					
					eval {
						$p_domain->[DOMAIN_INSTANCE] = $p_domain->[BACKEND]->new($p_domain->[BACKEND_INICFG],$p_domain->[BACKEND_CFG]);
					};
					
					if($@) {
						print STDERR "ERROR INST: $@\n";
						Carp::croak($p_domain->[BACKEND] . " could not be required. Reason: $@");
					}
				}
				
				$domainInstance = $p_domain->[DOMAIN_INSTANCE];
			}
		}
		
		return $domainInstance;
	}
}

our $jserr = JSON->new->convert_blessed();


package EPICO::REST::API;

use Dancer2;
use Dancer2::Serializer::JSON;
use Dancer2::Session::YAML;

set engines => {
	'serializer' => {
		'JSON' => {
			'convert_blessed' => 1,
			'utf8'	=>	1
		}
	},
	'deserializer' => {
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
set serializer => 'JSON';

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
		return $domainInstance->getModel();
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

prefix '/:domain_id' => sub {
	get ''	=>	\&getDomain;
	get '/model'	=>	\&getModel;
	prefix '/model/CV' => sub {
		get ''	=>	\&getAvailableCVs;
		get '/:cv_id'	=>	\&getCV;
		get '/:cv_id/terms'	=>	\&getCVterms;
		post '/:cv_id/terms'	=>	\&getCVterms;
		get '/:conceptDomainName/:conceptName/:columnName'	=>	\&getCVsFromColumn;
		get '/:conceptDomainName/:conceptName/:columnName/terms'	=>	\&getCVtermsFromColumn;
		post '/:conceptDomainName/:conceptName/:columnName/terms'	=>	\&getCVtermsFromColumn;
	};
};

package main;

use Plack::Builder;
builder {
# Enabling this we get some issues, so disabled for now
#	enable 'Deflater', content_type => ['text/plain','text/css','text/html','text/javascript','application/javascript','application/json'];
	enable 'CrossOrigin', origins => '*';
	mount '/'    => EPICO::REST::API->to_app;
};
