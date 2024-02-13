package Simplist::Scope;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use Data::Dump qw(pp);

@EXPORT_OK = qw(root_scope);

sub root_scope {
  bless {type => 'root', export => {}}
};

sub child {
  my ($parent, $type) = @_;
  bless {parent => $parent, type => $type};
}

sub assign {
  my ($scope, $name, $value) = @_;
  $scope->{names}{$name} = $value;
}

sub export {
  my ($scope, $name, $value) = @_;
  die "Cannot export outside root scope" unless $scope->{type} eq 'root';
  $scope->{export}{$name} = $value;
  $scope->assign($name, $value);
}

sub set {
  my ($scope, $name, $value) = @_;
  if ($scope->{type} eq 'root') {
    $scope->assign($name, $value);
  } else {
    die 'NYI set (traverses parent)';
  }
}

sub resolve {
  my ($scope, $id) = @_;
  return $scope->{names}{$id} if defined $scope->{names}{$id};
  return $scope->{parent}->resolve($id) if defined $scope->{parent};
  die "no such identifier: $id";
}

1;
