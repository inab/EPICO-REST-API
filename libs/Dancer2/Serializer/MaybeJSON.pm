package Dancer2::Serializer::MaybeJSON;
# ABSTRACT: Serializer for handling JSON data
$Dancer2::Serializer::MaybeJSON::VERSION = '0.204001';
use Moo;
use JSON::MaybeXS ();
use Scalar::Util 'blessed';

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'application/json'} );

# helpers
sub from_json { __PACKAGE__->deserialize(@_) }

sub to_json { __PACKAGE__->serialize(@_) }

sub decode_json {
    my ( $entity ) = @_;

	eval {
	    return JSON::MaybeXS::decode_json($entity);
	};

	if($@) {
		warn "Returning raw, due $@";
		return $entity;
	}
}

sub encode_json {
    my ( $entity ) = @_;

    JSON::MaybeXS::encode_json($entity);
}

# class definition
sub serialize {
    my ( $self, $entity, $options ) = @_;

    my $config = blessed $self ? $self->config : {};

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless exists $options->{$_};
    }

    $options->{utf8} = 1 if !defined $options->{utf8};
    JSON::MaybeXS->new($options)->encode($entity);
}

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    $options->{utf8} = 1 if !defined $options->{utf8};
	eval {
	    return JSON::MaybeXS->new($options)->decode($entity);
	};

	if($@) {
		warn "Returning raw, due $@";
		return $entity;
	}
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Serializer::MaybeJSON - Serializer for handling JSON data (and deserialize if it is possible)

=head1 VERSION

version 0.204001

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
JSON output and vice-versa.

=head1 ATTRIBUTES

=head2 content_type

Returns 'application/json'

=head1 METHODS

=head2 serialize($content)

Serializes a Perl data structure into a JSON string.

=head2 deserialize($content)

Deserializes a JSON string into a Perl data structure.

=head1 FUNCTIONS

=head2 from_json($content, \%options)

This is an helper available to transform a JSON data structure to a Perl data structures.

=head2 to_json($content, \%options)

This is an helper available to transform a Perl data structure to JSON.

Calling this function will B<not> trigger the serialization's hooks.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
