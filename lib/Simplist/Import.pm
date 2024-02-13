package Simplist::Import;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use List::Util qw(sum0 product all);

@EXPORT_OK = qw(resolve_import);

my $stdlib = {
  '+' => {
    type => 'primitive_fn',
    value => sub {
      die unless all { $_->{type} eq 'num'; } @_;
      return {
        type => 'num',
        value => sum0(map { $_->{value} } @_)
      };
    },
  },
  'list' => {
    type => 'primitive_fn',
    value => sub {
      return {
        type => 'list',
        exprs => \@_
      };
    },
  }
};

sub resolve_import {
use Data::Dump qw(pp);
  my $package = shift;
  if ($package eq 'std') {
    return $stdlib
  } else {
    die "NYI module loading";
  }
}

1
