EPICO / BLUEPRINT Data Analysis Portal REST API installation
====================================================

This document explains how to install and setup EPICO / BLUEPRINT Data Analysis Portal REST API.

Dependencies
------------

This software is written in Perl, and it depends on Dancer2, Plack, FCGI and Elasticsearch.
The detailed dependencies are:

* Dancer2
* Plack::Middleware::CrossOrigin
* Plack::Middleware::Deflater
* FCGI	(needed by Plack::Handler::FCGI)
* BP-Schema-tools
* A web server with a proper setup.

## Deployment
1. Check you have installed gcc, cpan, the development version of Perl.

2. Create a separate user (for instance, `epico-rest`) for the API, with a separate group

	```bash
	useradd -m -U -c 'EPICO REST API unprivileged user' epico-rest
	```

3. As the user `epico-rest`, install the needed Perl modules and dependencies

4. Clone this code, in order to install the API:

	```bash
	git clone --recurse-submodules https://github.com/inab/EPICO-REST-API.git
	cd EPICO-REST-API
	```

5. Create directory `DOCUMENT_ROOT`, and copy next content there:

	```bash
	mkdir -p "${HOME}"/DOCUMENT_ROOT/cgi-bin
	cp -dpr epico-rest epico-rest.psgi libs BP-Schema-tools config "${HOME}"/DOCUMENT_ROOT/cgi-bin
	```

6. You have to put inside `config` subdirectory the configuration files corresponding to the different enabled domains.

## Web server setup with a virtual host (in CentOS)

1. You have to install Apache and [http://mpm-itk.sesse.net/](MPM ITK):
	
	```bash
	yum install -y httpd httpd-itk
	```

2. Now, we switch on MPM ITK *without switching off* MPM prefork:

	```bash
	sed -i 's/^#\(LoadModule \)/\1/' /etc/httpd/conf.modules.d/00-mpm-itk.conf
	```

3. As CentOS does not come with the virtual hosts infrastructure for Apache, we have to create it, and include its usage in the configuration file:

	```bash
	mkdir -p /etc/httpd/sites-available /etc/httpd/sites-enabled
	echo 'IncludeOptional sites-enabled/*.conf' >> /etc/httpd/conf/httpd.conf
	```

4. Copy configuration file apache/RD-Connect.conf to `/etc/httpd/sites-enabled`
