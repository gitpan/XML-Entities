#!/usr/bin/perl

=encoding utf8

This script downloads the definitions of XML entities from
http://www.w3.org/2003/entities/iso9573-2003/ or from whatever
address you give it as an argument. The argument should be
an URL (that LWP::Simple::get can access) pointing to a document
with (absolute or relative) references to files ending with the
C<.ent> suffix. These files are expected to be DTD's with
lines like

 <!ENTITY amp "&#38;" >

The script parses these files and prints the perl module to the
standard output. If you wish, you can give "file" as another
argument to the script and it will then print it to "file".
You can also specify the output file in the environment variable
OUTPUT_FILE.

The index and the output file are distinguished by the presence
of "://" substring.
If you want to use a locally stored index file (the one with the
.ent references), you can access it by saying

 perl download.pl file:///path/to/index.html

Note that the script currently distinguishes between relative
and absolute paths by looking at whether the href contains a "://"
substring. This can lead to crashes when the links look like
href="/path/file.ent".

Also, the script assumes the links have exactly the format
C<href="..."> - with double quotes.

=cut

use strict;
use warnings;
use Carp;
use LWP::Simple;
use File::Basename;
use Fatal 'open';

sub parse_ent;
sub format_output_perlmod_hashsubs0;

my $I = ' ' x 4;  # Indentation;
my $out_fn = $ENV{'OUTPUT_FILE'};
my $index_url;

ARG:
for (@ARGV) {
    if (m{://}) {
        if (defined $index_url) {
            croak "Index doubly defined ('$index_url' and  '$_')"
        }
        $index_url = $_;
        next ARG;
    }
    if (defined $out_fn) {
        croak "Output file doubly defined ('$out_fn', '$_')"
    }
    $out_fn = $_;
    next ARG;
}
if (not defined $index_url) {
    $index_url = 'http://www.w3.org/2003/entities/iso9573-2003doc/overview.html';
}

# load the entity declarations from the web
print STDERR "Downloading the list of documents\n";
my $index = LWP::Simple::get($index_url);
die qq/Couldn't download the index ('$index_url' where the .ent files are listed)/ if not defined $index;
my @doc_hrefs_relative = $index =~ /(?<=href=") [^"]+\.ent (?=")/sgx;
my @doc_hrefs = map { m{://} ? $_ : dirname($index_url) . '/' . $_ } @doc_hrefs_relative;
my @doc_names = map { my ($name) = fileparse($_, '.ent'); $name } @doc_hrefs;
print STDERR "Downloading the documents\n";
my @ent_declarations = map get($_) || die (qq/Couldn't download the declarations for $_/), @doc_hrefs;
#my @doc_names = qw(isobox isocyr1 isocyr2 isodia isolat1 isolat2 isonum isopub isoamsa isoamsb isoamsc isoamsn isoamso isoamsr isogrk1 isogrk2 isogrk3 isogrk4 isomfrk isomopf isomscr isotech);
#my @ent_declarations = map { open my $fh, '<', $_; local $/; <$fh> } glob('ent_files/*.ent');

# parse the .ent files and save them in arrays
print STDERR "Parsing the documents... ";
my %ent_definitions;
for my $i (0 .. $#doc_names) {
    $ent_definitions{ $doc_names[$i] } = parse_ent( \$ent_declarations[$i] );
}

# Decide where to output
my $out_fh; # output filehandle - STDOUT by default;
if (defined $out_fn) {
    open $out_fh, '>', $out_fn;
}
else {
    $out_fh = \*STDOUT;
}

print $out_fh format_output_perlmod_hashsubs0(\@doc_names, \%ent_definitions);
print STDERR "Done\n";

# Get (preferably a reference to) a string that contains lines like:
# <!ENTITY amp           "&#38;" >
# <!ENTITY apos          "&#x00027;" >
# Return [ ['amp', 'chr(38)'], ['apos', 'chr(0x0027)'] ]
sub parse_ent {
    my ($ent_file_ref) = @_;
    if (not ref $ent_file_ref) { $ent_file_ref = \$ent_file_ref }
    my @raw_defs = $$ent_file_ref =~ /(?<=<!ENTITY) \s* \w+ \s+ "&[^"]+" (?=\s*>)/sgx;
    my @name_value_pairs = map {my ($n, $v) = /(\w+) \s* "&\# ([^"]+) "/sx; [$n, $v]} @raw_defs;
    for (@name_value_pairs) {
        my $v = $$_[1];
        # For some reason, some entities like &lt; are defined like &#38;#60; instead of &#60; - just get rid of 38;#
        $v =~ s/38;#//g;
        $v =~ s/^x/0x/;
        $v =~ s/;$//;
        $v = "chr($v)";
        # Some entities have more than 1 char.
        $v =~ s/;&#x/).chr(0x/g;
        $v =~ s/;&#/).chr(/g;
        $v =~ /^ (?: \.? chr\( (?: 0x[0-9ABCDEF]+ | [1-9][0-9]* ) \) )+ $/ix
        or croak "The entity definition '$$_[0] => $v' doesn't seem sane";
        $$_[1] = $v;
    }
    return \@name_value_pairs;
}


sub format_output_perlmod_hashsubs0 {

my $header = <<'EOPERL';
package XML::Entities::Data;
use strict;
my @names;
EOPERL

my $footer = <<'EOPERL';

sub all {
    no strict 'refs';
    return {map %{$_->()}, @names}
}

sub names {
    return @names
}

sub char2entity {
    my ($subname) = @_;
    no strict 'refs';
    my $ent2char = $subname->();
    use strict;
    my %char2ent;
    while (my($entity, $char) = each(%$ent2char)) {
        $entity =~ s/;\z//;
        $char2ent{$char} = "&$entity;";
    }
    return \%char2ent;
}

1
EOPERL

    # This is the actual beginning of sub format_output_perlmod_hashsubs0
    my ($doc_names, $ent_definitions, $I) = @_;
    # I as in Indentation
    $I = ' ' x 4 if not defined $I;
    my $rv = $header;
    for (0 .. $#$doc_names) {
        my $name = $doc_names->[$_];
        my $definition_array = $ent_definitions->{ $name };
        
        # Start of the entity set "$name"
        $rv .= 
            "\n# " . uc($name) . "\n"
          . "push \@names, '$name';\n"
          . "{ my \$rv; sub $name {\n"
          . "$I# Return cached value if there is one.\n"
          . "${I}if (\$rv) { return \$rv }\n"
          . "${I}return \$rv = {\n";
        
        # The entity definitions
        for my $definition (@$definition_array) {
            my $n = $definition->[0];
            my $v = $definition->[1];
            $rv .= "$I$I'$n' => $v,\n";
        }
        
        # End of the entity set
        $rv .= "$I}\n}}\n";
    }
    $rv .= $footer;
    
    return $rv
}
