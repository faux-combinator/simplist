package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use Simplist::Scope qw(root_scope);
use List::Util qw(any);
use Data::Dump qw(pp);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(evaluate);

# TODO let should just be a macro that uses lambda underneath...
my @specials = qw(let lambda eval);

sub evaluate_node {
  my ($runtime, $scope, $node) = @_;
  my $method = "run_$node->{type}";
  $runtime->$method($scope, $node);
}

sub evaluate_nodes {
  my ($runtime, $scope, $nodes) = @_;
  map { evaluate_node($runtime, $scope, $_) } @{$nodes};
}

sub is_special_call {
  my $fn = shift;
  $fn->{type} eq "id" && any { $_ eq $fn->{value} } @specials;
}

# (CALLABLE PARAM...)
# TODO cleanup this mess.
# extract the scope-resolve code
#  and probably the dispatch on fn/primitive_call
sub run_list {
  my ($runtime, $scope, $node) = @_;
  die "invalid call: empty call" unless @{$node->{exprs}};
  my $fn = shift @{$node->{exprs}};
  if (is_special_call($fn)) {
    my $method = "run_$fn->{value}";
    return $runtime->$method($scope, $node);
  }

  $fn = evaluate_node($runtime, $scope, $fn);
  my @values = evaluate_nodes($runtime, $scope, $node->{exprs});
  die "not callable: $fn->{type}" unless $fn->{type} =~ /fn$/;

  if ($fn->{type} eq 'primitive_fn') {
    $fn->{value}(@values);
  } else {
    $runtime->run_lambda_call($scope, $fn, \@values);
  }
}

sub run_primitive_fn {
  my ($runtime, $scope, $node) = @_;
  $node;
}

sub check_argument_count {
  my $num_got = scalar @{shift()};
  my $num_wants = scalar @{shift()};
  die "Invalid number of arguments. Got $num_got, expected $num_wants"
    if $num_got != $num_wants;
}

sub run_lambda_call {
  # $outer_scope is the dynamic scope.
  my ($runtime, $outer_scope, $fn, $values) = @_;
  my $scope = $fn->{scope};
  my @param_names = @{$fn->{param_names}};

  my $new_scope = $scope->child;
  my @values = @{$values};
  for my $name (@param_names) {
    $new_scope->assign($name, shift @values);
  }

  evaluate_node($runtime, $new_scope, $fn->{body});
}

# (let NAME VALUE EXPR)
sub run_let {
  my ($runtime, $scope, $node) = @_;
  my ($name, $value, $expr) = @{$node->{exprs}};
  die "cannot let a non-id" unless $name->{type} eq "id";
  my $new_scope = $scope->child;
  $new_scope->assign($name->{value}, evaluate_node($runtime, $scope, $value));
  return evaluate_node($runtime, $new_scope, $expr);
}

# (eval EXPR)
# NOTE: (eval (list + 34 56))
#       will currently fail to eval because + will have been evaluate_node'd,
#       and thus it will be (0 34 56) (0 = empty call of +)
sub run_eval {
  my ($runtime, $scope, $node) = @_;
  my @exprs = @{$node->{exprs}};
  die "eval can only eval one thing" if @exprs != 1;
  
  my ($expr) = @exprs;
  my $result = evaluate_node($runtime, $scope, $expr);
  evaluate_node($runtime, $scope, $result);
};

# (lambda (PARAM ...) BODY)
sub run_lambda {
  my ($runtime, $scope, $node) = @_;
  # extract scope, parameters and body
  my @parts = @{$node->{exprs}};
  die 'invalid syntax to lambda' if scalar @parts != 2;

  # the first () is the params, the 2nd is the body
  my ($params, $body) = @parts;

  my @params = @{$params->{exprs}};
  die 'parameters must be identifiers' if any { $_->{type} ne 'id' } @params;
  my @param_names = map { $_->{value} } @params;
  $node->{param_names} = \@param_names;

  # store the scope (lexical scoping ftw!)
  $node->{scope} = $scope;
  # we don't allow variadic lambdas (only one expression).
  undef $node->{exprs};
  $node->{body} = $body;
  $node->{type} = 'fn';
  $node;
}

# 'EXPR
sub run_quote {
  my ($runtime, $scope, $node) = @_;
  my @values;


  #for my $expr (@{$node->{exprs}}) {
  #  die "nested not handled" if $expr->{type} eq "list";
  #  # TODO need to deeply replace calls with arrays
  #  # rewrite `id` to `str` (XXX should be symbol or what?)
  #  $expr->{type} = "symbol" if $expr->{type} eq "id";
  #  push @values, $expr;
  #}
  return $node->{expr};
}

sub run_num {
  my ($runtime, $scope, $node) = @_;
  $node;
}

sub run_id {
  my ($runtime, $scope, $node) = @_;
  $scope->resolve($node->{value});
}

sub evaluate {
  my $runtime = bless {nodes => shift};
  my $scope = root_scope;
  my @results = evaluate_nodes($runtime, $scope, $runtime->{nodes});
  # only return the last result
  $results[-1];
}

1;
