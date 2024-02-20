package Simplist::Import;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use File::Slurp;
use List::Util qw(sum0 product all);
use Data::Dump qw(pp);

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

  'list/at' => {
    type => 'primitive_fn',
    value => sub {
      die "Needs an array and an index" unless @_ eq 2;
      my ($array, $idx) = @_;
      die "Can only index lists" unless $array->{type} eq 'list';
      my $len = scalar @{$array->{exprs}};

      die "Index needs to be a number" unless $idx->{type} eq 'num';
      my $index = $idx->{value};

      die "Index $index is out of bounds for array of size $len" if $index < 0 or $index >= $len;
      return $array->{exprs}[$index];
    },
  },

  'list/length' => {
    type => 'primitive_fn',
    value => sub {
      die "Length expects a single argument" unless @_ eq 1;
      my $array = shift;
      return {
        type => 'num',
        value => scalar @{$array->{exprs}}
      }
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
  die "File not found: $fullpath" unless -f $fullpath;
  my $content = read_file $fullpath;
  $loader->($content);
}

1
