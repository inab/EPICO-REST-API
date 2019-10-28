#!/usr/bin/perl
# BLUEPRINT Data Analysis Portal REST API
# José María Fernández (jose.m.fernandez@bsc.es)

use strict;
use warnings 'all';

use Carp;
use File::Spec;
use JSON -no_export;

use FindBin;

# This is needed to locate the different maps
use EPICO::REST::Backend;
use File::ShareDir;

package EPICO::REST::Common;

use constant RELATIVE_CONFIG_DIR	=>	'config';
use constant CONFIG_DIR	=>	File::Spec->catdir($FindBin::Bin,RELATIVE_CONFIG_DIR);

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
	# Backend maps are read on first call
	my %backendMap = ();
	
	sub readBackendMaps() {
		if(scalar(keys(%backendMap))==0) {
			eval {
				# Any EPICO REST backend must place its maps files
				# under the module dir of EPICO::REST::Backend
				my $module_dir = File::ShareDir::module_dir('EPICO::REST::Backend');
				
				# Now, trying to read all the .map files from all the installed backends
				if(opendir(my $MD,$module_dir)) {
					while(my $entry = readdir($MD)) {
						if($entry =~ /\.map$/) {
							my $fileentry = File::Spec->catfile($module_dir,$entry);
							
							if(open(my $FE,'<:encoding(UTF-8)',$fileentry)) {
								my $module_name = <$FE>;
								close($FE);
								
								# It removes the file suffix, keeping the name as the key
								my $key = substr($entry,0,-4);
								$backendMap{$key} = chomp($module_name);
							}
						}
					}
					closedir($MD);
				}
			};
		}
		
		return \%backendMap;
	}
}

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
				
				my $p_backendMap = readBackendMaps();
				while(my $entryName = readdir($CONFDIR)) {
					if($entryName =~ /\.ini$/) {
						my $fullEntryName = File::Spec->catfile(CONFIG_DIR,$entryName);
						if(-f $fullEntryName && -r $fullEntryName) {
							my $cfg = Config::IniFiles->new( -file => $fullEntryName);
							
							if($cfg->SectionExists(EPICO_API_SECTION) && $cfg->exists(EPICO_API_SECTION,NAME_PARAMETER) && $cfg->exists(EPICO_API_SECTION,RELEASE_PARAMETER) && $cfg->exists(EPICO_API_SECTION,BACKEND_PARAMETER)) {
								my $domainName = $cfg->val(EPICO_API_SECTION,NAME_PARAMETER);
								my $release = $cfg->val(EPICO_API_SECTION,RELEASE_PARAMETER);
								my $backendName = $cfg->val(EPICO_API_SECTION,BACKEND_PARAMETER);
								
								if(exists($p_backendMap->{$backendName})) {
									my $domain_id = $backendName.':'.$release;
									$domains{$domain_id} = [undef,$p_backendMap->{$backendName},$cfg,$fullEntryName,$domain_id,$domainName,$release];
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

1;