package XML::Entities;

=head1 NAME

XML::Entities - Decode strings with XML entities

=head1 SYNOPSIS

 use XML::Entities;

 $a = "Tom &amp; Jerry &copy; Warner Bros&period;"
 XML::Entities::decode($a);

=head1 DESCRIPTION

Based upon the HTML::Entities module by Gisle Aas

This module deals with decoding of strings with XML
character entities.  The module provides one function:

=over 4

=item decode( $entity_set, $string, ... )

This routine replaces XML entities from $entity_set found in the
$string with the corresponding Unicode character. Unrecognized
entities are left alone.

The $entity_set can either be a name of an entity set - the selection
of which can be obtained by XML::Entities::Data::names(), or "all" for
a union, or alternatively a hashref which maps entity names (without
leading &'s) to the corresponding Unicode characters (or strings).

If multiple strings are provided as argument they are each decoded
separately and the same number of strings are returned.

If called in void context the arguments are decoded in-place.

=back

=head2 XML::Entities::Data

The list of entities is defined in the XML::Entities::Data module.
The list can be generated from the w3.org definition (or any other).
Check C<perldoc XML::Entities::Data> for more details.

=head1 SEE ALSO

HTML::Entities, XML::Entities::Data

=head1 COPYRIGHT

Copyright 2007 Oldrich Kruza Oldrich.Kruza@sixtease.net. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

use strict;
require 5.007;    # because we're passing semicolon-terminated entities to HTML::Entities::_decode_entities;
use Carp;
use XML::Entities::Data;
require HTML::Parser;  # for fast XS implemented decode_entities

our $VERSION = '0.01';
sub Version { $VERSION; }

sub decode {
    my $set = shift;
    my @set_names = XML::Entities::Data::names;
    my $entity2char;
    if (ref $set eq 'HASH') {
        $entity2char = $set;
    }
    else {
        croak "'$set' is not a valid entity set name. Choose one of: all @set_names"
        if not grep {$_ eq $set} 'all', @set_names;
        no strict 'refs';
        $entity2char = "XML::Entities::Data::$set"->();
        use strict;
    }
    if (defined wantarray) {
        my @strings = @_;
        HTML::Entities::_decode_entities($_, $entity2char) for @strings;
        return @strings[0 .. $#strings]
    }
    else {
        HTML::Entities::_decode_entities($_, $entity2char) for @_;
    }
}

1
