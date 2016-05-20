package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use Data::Dump qw(pp);
use List::Util qw(sum0 product map);

@EXPORT_OK = qw(root_scope);

sub root_scope {
  my $scope = bless {};
  $scope->{names}{'+'} = sub {
    # TODO check that works
    # die unless all { $_->{type} eq 'num'; } @_;
    return {
      type => 'num',
      value => sum0(map { $_->{value} } @_)
    };
  };

=begin
  $scope->{names}{'*'} = sub {
    # TODO assert all are num
    product(@_);
  };
  $scope->{names}{length} = sub {
    my $array = shift;
    scalar @{$array};
  };
  $scope->{names}{at} = sub {
    my ($array, $index) = @_;
    return $array->[$index];
  };
=end

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
