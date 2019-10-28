# EPICO / BLUEPRINT Data Analysis Portal REST API installation

This document explains how to install and setup EPICO / BLUEPRINT Data Analysis Portal REST API.

## Dependencies

This software is written in Perl, and it depends on Dancer2, Plack, FCGI and Elasticsearch.
The detailed dependencies are in [cpanfile](cpanfile), which are used by carton.

## Deployment
1. Check you have installed gcc, cpan, the development version of Perl.

2. Create a separate user (for instance, `epico-rest` with group `epico-rest`) for the API, with a separate group

	```bash
	useradd -m -U -c 'EPICO REST API unprivileged user' epico-rest
	```

3. As the user `epico-rest`, install the needed Perl modules and dependencies

4. Clone this code, in order to install the API and its dependencies:

	```bash
	git clone -b fairtracks https://github.com/inab/EPICO-REST-API.git
	cd EPICO-REST-API
	carton install --deployment --without develop
	```

5. Install one or more backends, defined in cpanfile-like files:

	```bash
	carton install --cpanfile cpanfile-es-backend
	carton install --cpanfile cpanfile-fairtracks-backend
	```

6. Put the profile configurations in `config` subdirectory. Each one of these files must contain what the backend needs, as well as `epico-api` section:

	```
	[epico-api]
	name=BLUEPRINT Release 2016-08
	release=2016-08
	backend=EPICO
	```

	which defines the backend to be used (currently, only [EPICO](https://github.com/inab/EPICO-ES-backend) and [FAIRTracks](https://github.com/inab/EPICO-FAIRTracks-backend) ones), the name used to publish this domain through the API, and the release. There cannot be two configuration files with the same `backend` and `release` parameters, as both of them are used to build the domain unique identifier.
	
	In the case of the [native backend](https://github.com/inab/EPICO-ES-backend), the configuration file must contain the database connection parameters, database backend, etc... as defined for [EPICO data loading scripts](https://github.com/inab/EPICO-data-loading-scripts/tree/fairtracks).
	

7. Create an installation directory (for instance, `/home/epico-rest/EPICO-REST-API`), and copy at least next content there:

	```bash
	mkdir -p "${HOME}"/EPICO-REST-API
	cp -dpr epico-rest.cgi epico-rest.fcgi epico-rest.psgi config libs local "${HOME}"/EPICO-REST-API
	```

## Apache Web server setup with a virtual host (in CentOS and Ubuntu)

1. You have to install and setup Apache:
	
	```bash
	# This is for CentOS
	yum install -y httpd
	```
	
	```bash
	# This is for Ubuntu
	apt-get install apache2
	```

2. If you are going to use `epico-rest.cgi`, you optionally have to install [MPM ITK](http://mpm-itk.sesse.net/) and enable it *without switching off* MPM prefork, in order to run it as the user you have created:
	
	```bash
	# This is for CentOS
	yum install -y httpd-itk
	sed -i 's/^#\(LoadModule \)/\1/' /etc/httpd/conf.modules.d/00-mpm-itk.conf
	```
	
	```bash
	# This is for Ubuntu
	apt-get install libapache2-mpm-itk
	a2enmod mpm_itk
	```
	
	Next, you have to enable `cgi` module:
	
	```bash
	# This is for Ubuntu
	a2enmod cgi
	```
	
	You have to put next Apache configuration block inside de virtualhost definition, in order to enable the API handler at /epico-api:
	
	```
	<IfModule mpm_itk_module>
		AssignUserId epico-rest epico-rest
	</IfModule>
	
	# This line is needed if you locally installed the Perl modules needed
	SetEnv PERL5LIB /home/epico-rest/perl5/lib/perl5
	
	ScriptAlias "/epico-api" "/home/epico-rest/EPICO-REST-API/epico-rest.cgi"
	<Directory /home/epico-rest/EPICO-REST-API>
		AllowOverride None
		SetHandler cgi-script
		Options ExecCGI SymLinksIfOwnerMatch
		
		# These sentences are for Apache 2.2 and Apache 2.4 with mod_access_compat enabled
		<IfModule !mod_authz_core.c>
			Order allow,deny
			Allow from all
		</IfModule>
		
		# This sentence is for Apache 2.4 without mod_access_compat
		<IfModule mod_authz_core.c>
			Require all granted
		</IfModule>
	</Directory>
	```
	
3. If you are going to use `epico-rest.fcgi` you have to install [https://httpd.apache.org/mod_fcgid/mod/mod_fcgid.html](mod_fcgid):

	
	```bash
	# This is for CentOS
	yum install -y mod_fcgid
	```
	
	```bash
	# This is for Ubuntu
	apt-get install libapache2-mod-fcgid
	a2enmod fcgid
	```
	
	You optionally have to install [https://httpd.apache.org/docs/2.4/mod/mod_suexec.html](mod_suexec), if you want the FCGI run as `epico-rest`
	
	```bash
	# This is for Ubuntu
	apt-get install apache2-suexec
	a2enmod suexec
	```

	You have to put next Apache configuration block inside de virtualhost definition, in order to enable the API handler at /epico-api:
	
	```
	<IfModule mod_suexec>
		SuexecUserGroup epico-rest epico-rest
	</IfModule>
	
	
	FcgidIOTimeout 300
	FcgidMaxRequestLen 104857600
	# This line is only needed if you locally installed the Perl modules needed
	FcgidInitialEnv PERL5LIB /home/epico-rest/perl5/lib/perl5
	
	ScriptAlias "/epico-api/" "/home/epico-rest/EPICO-REST-API/epico-rest.fcgi/"
	<Directory /home/epico-rest/EPICO-REST-API>
		AllowOverride None
		SetHandler fcgid-script
		Options ExecCGI SymLinksIfOwnerMatch
		
		# These sentences are for Apache 2.2 and Apache 2.4 with mod_access_compat enabled
		<IfModule !mod_authz_core.c>
			Order allow,deny
			Allow from all
		</IfModule>
		
		# This sentence is for Apache 2.4 without mod_access_compat
		<IfModule mod_authz_core.c>
			Require all granted
		</IfModule>
	</Directory>
	```
