package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use Simplist::Scope qw(root_scope);
use Data::Dump qw(pp);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(evaluate);

sub evaluate {
  my $runtime = bless {nodes => shift};
  my $scope = root_scope;
  evaluate_nodes($runtime, $scope, $runtime->{nodes});
}

sub evaluate_nodes {
  my ($runtime, $scope, $nodes) = @_;
  my @values;
  while (my $node = shift @{$nodes}) {
    my $method = "run_$node->{type}";
    # TODO pass scope or some other stuff
    push @values, $runtime->$method($scope, $node);
  }
  @values
}

sub run_call {
  my ($runtime, $scope, $node) = @_;
  my $fn = shift @{$node->{exprs}};
  die "not callable" unless $fn->{type} eq "id";
  my @values = evaluate_nodes($runtime, $scope, $node->{exprs});

  my $symbol = $scope->resolve($fn->{value});
  die unless ref($symbol) eq "CODE";
  $symbol->(@values);
};

sub run_num {
  my ($runtime, $scope, $node) = @_;
  $node->{value};
};

sub run_id {
  my ($runtime, $scope, $node);
  $scope->resolve($node->{value});
}
