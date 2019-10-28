# Local dependencies
requires 'boolean';
requires 'File::Spec';
requires 'File::Temp';
requires 'Carp';
requires 'Config::IniFiles';
requires 'File::ShareDir';
requires 'JSON';
requires 'Dancer2';
requires 'Plack::Middleware::CrossOrigin';
requires 'Plack::Middleware::Deflater';
requires 'FCGI';

# Dependencies needed by MaybeJSON
requires 'Moo';
requires 'JSON::MaybeXS';
requires 'Scalar::Util';

# Dependencies by EPICO API

requires 'EPICO::REST::Backend', 'v1.0.1', url => 'https://github.com/inab/EPICO-abstract-backend/archive/v1.0.1.tar.gz';
