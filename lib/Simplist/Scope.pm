package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use Data::Dump qw(pp);
use List::Util qw(sum0 product);

@EXPORT_OK = qw(root_scope);

sub root_scope {
  my $scope = bless {};
  $scope->{names}{'+'} = sub {
    # TODO assert all are num
    sum0(@_);
  };
  $scope->{names}{'*'} = sub {
    product(@_);
  };
  $scope
};

sub child {
  my $parent = shift;
  my $scope = bless {};
  $scope->{parent} = $parent;
  $scope
}

sub assign {
  my ($scope, $name, $value) = @_;
  $scope->{names}{$name} = $value;
}

sub set {
  die 'NYI set (traverses parent)';
}

sub resolve {
  my ($scope, $id) = @_;
  return $scope->{names}{$id} if (defined $scope->{names}{$id});
  return $scope->{parent}->resolve($id) if (defined $scope->{parent});
  die "no such identifier: $id";
}
