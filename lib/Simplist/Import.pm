package Simplist::Import;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use File::Slurp;
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
  },
  'say' => {
    type => 'primitive_fn',
    value => sub {
      for my $el (@_) {
        if ($el->{type} eq 'num') {
          say $el->{value};
        } else {
          die "NYI say for $el->{type}";
        }
      }
      return {
        type => 'list',
        exprs => []
      };
    },
  }
};

sub resolve_import {
use Data::Dump qw(pp);
  my ($package, $loader) = @_;
  if ($package eq 'std') {
    return $stdlib
  }
 
  die "Cannot import without a defined SIMPLIST_PATH" unless exists $ENV{SIMPLIST_PATH};
  my $fullpath = "$ENV{SIMPLIST_PATH}/$package.simpl";
  die "NYI module loading" unless -f $fullpath;
  my $content = read_file $fullpath;
  $loader->($content);
}

1
