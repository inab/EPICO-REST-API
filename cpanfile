# Local dependencies
requires 'Dancer2';
requires 'Plack::Middleware::CrossOrigin';
requires 'Plack::Middleware::Deflater';
requires 'FCGI';

# Dependencies needed by MaybeJSON
requires 'Moo';
requires 'JSON::MaybeXS';
requires 'Scalar::Util';

# Dependencies by EPICO native backend
requires 'File::Basename';
requires 'File::Spec';
requires 'Log::Log4perl';

# Dependencies by EPICO API
requires 'boolean';
requires 'Carp';
requires 'Config::IniFiles';
requires 'Log::Log4perl';
requires 'Scalar::Util';

requires 'TabParser', '0.01', url => 'https://github.com/inab/TabParser/archive/0.01.tar.gz';

requires 'BP::Model', 'v1.1.1', url => 'https://github.com/inab/BP-Model/archive/v1.1.1.tar.gz';

requires 'BP::Loader', 'v1.0.2', url => 'https://github.com/inab/BP-Schema-tools/archive/v1.0.2.tar.gz';

# This is not needed in this project
#requires 'BP::DCCLoader', 'v1.0.0', url => 'https://github.com/inab/EPICO-data-loading-scripts/archive/v1.0.0.tar.gz';
