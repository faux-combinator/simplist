package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use Simplist::Scope qw(root_scope);
use List::Util qw(any);
use Data::Dump qw(pp);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(evaluate);

my @specials = qw(let);

sub evaluate {
  my $runtime = bless {nodes => shift};
  my $scope = root_scope;
  evaluate_nodes($runtime, $scope, $runtime->{nodes});
}

sub evaluate_nodes {
  my ($runtime, $scope, $nodes) = @_;
  my @values;
  while (my $node = shift @{$nodes}) {
    push @values, evaluate_node($runtime, $scope, $node);
  }
  @values
}

sub evaluate_node {
  my ($runtime, $scope, $node) = @_;
  my $method = "run_$node->{type}";
  return $runtime->$method($scope, $node);
}

sub run_call {
  my ($runtime, $scope, $node) = @_;
  my $fn = shift @{$node->{exprs}};
  die "not callable" unless $fn->{type} eq "id"; # TODO allow lambdas
  if (any { $_ eq $fn->{value} } @specials) {
    my $method = "run_$fn->{value}";
    return $runtime->$method($scope, $node);
  }
  my @values = evaluate_nodes($runtime, $scope, $node->{exprs});

  my $symbol = $scope->resolve($fn->{value});
  die unless ref($symbol) eq "CODE";
  $symbol->(@values);
}

sub run_let {
  my ($runtime, $scope, $node) = @_;
  my ($name, $value, $expr) = @{$node->{exprs}};
  die "cannot let a non-id" unless $name->{type} eq "id";
  my $new_scope = $scope->child;
  $new_scope->assign($name->{value}, evaluate_node($runtime, $scope, $value));
  return evaluate_node($runtime, $new_scope, $expr);
}

sub run_num {
  my ($runtime, $scope, $node) = @_;
  $node->{value};
}

sub run_id {
  my ($runtime, $scope, $node) = @_;
  $scope->resolve($node->{value});
}
