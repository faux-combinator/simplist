package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use Simplist::Scope qw(root_scope);
use Simplist::Import qw(resolve_import);
use List::Util qw(any);
use Data::Dump qw(pp);

@EXPORT_OK = qw(evaluate);

# TODO let should just be a macro that uses lambda underneath...
my @specials = qw(let lambda eval macro export import);

sub evaluate_node {
  my ($runtime, $scope, $node) = @_;
  my $method = "run_$node->{type}";
  $runtime->$method($scope, $node);
}

sub evaluate_nodes {
  my ($runtime, $scope, $nodes) = @_;
  map { evaluate_node($runtime, $scope, $_) } @$nodes;
}

sub is_special_call {
  my $fn = shift;
  $fn->{type} eq "id" && any { $_ eq $fn->{value} } @specials;
}

# (export NAME EXPR)
sub run_export {
  my ($runtime, $scope, $node) = @_;
  die "Export is only available at the top-level" if $scope->{parent};
  die "Export needs a name and a value" unless @{$node->{exprs}} == 2;
  my ($name, $value) = @{$node->{exprs}};
  die "Exported name should be a static identifier" unless $name->{type} eq 'id';
  my $result = evaluate_node($runtime, $scope, $value);
  $runtime->{export}{$name->{value}} = $result;
  $scope->assign($name->{value}, $result);
  $result # If it's the last statement
}

# (import LIBNAME (NAME...))
sub run_import {
  my ($runtime, $scope, $node) = @_;
  die "NYI import-as" if @{$node->{exprs}} == 1;
  die "Malformed import statement" unless @{$node->{exprs}} == 2;
  my ($package, $names) = @{$node->{exprs}};
  die "Exported name should be a static identifier" unless $package->{type} eq 'id';
  die "Import list should be a list" unless $names->{type} eq 'list';

  my $import = resolve_import($package->{value});
  die "Cannot resolve module $package->{value}" unless $import;
  for my $name (@{$names->{exprs}}) {
    die "Import name should be an identifier" unless $name->{type} eq 'id';
    die "Package $package->{value} has no $name" unless exists $import->{$name->{value}};
    $scope->assign($name->{value}, $import->{$name->{value}});
  }

  undef # TODO return the object/import-as
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
  if ($fn->{macro}) {
    return $runtime->run_macro_call($scope, $fn, $node->{exprs});
  }
  my @values = evaluate_nodes($runtime, $scope, $node->{exprs});
  die "not callable: $fn->{type}" unless $fn->{type} =~ /fn$/;

  if ($fn->{type} eq 'primitive_fn') {
    return $fn->{value}(@values);
  } else {
    $runtime->run_lambda_call($scope, $fn, \@values);
  }
}

sub check_argument_count {
  my $num_got = scalar @{shift()};
  my $num_wants = scalar @{shift()};
  die "Invalid number of arguments. Got $num_got, expected $num_wants"
    if $num_got != $num_wants;
}

sub run_lambda_call {
  # $outer_scope is the dynamic scope. we do not need it right now
  my ($runtime, $outer_scope, $fn, $values) = @_;
  my $scope = $fn->{scope};
  my @param_names = @{$fn->{param_names}};

  my $new_scope = $scope->child;
  my @values = @$values;
  for my $name (@param_names) {
    $new_scope->assign($name, shift @values);
  }

  my @results = evaluate_nodes($runtime, $new_scope, $fn->{body});
  $results[-1]
}

sub run_macro_call {
  my ($runtime, $outer_scope, $fn, $values) = @_;
  # eval the code in outer_scope, not the macro's scope
  return $runtime->evaluate_node($outer_scope, run_lambda_call(@_));
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
  die 'invalid syntax to lambda' if scalar @parts < 2;

  # the first () is the params, the 2nd is the body
  my ($params, @body) = @parts;

  my @params = @{$params->{exprs}};
  die 'parameters must be identifiers' if any { $_->{type} ne 'id' } @params;
  my @param_names = map { $_->{value} } @params;
  $node->{param_names} = \@param_names;

  # store the scope (lexical scoping ftw!)
  $node->{scope} = $scope;
  undef $node->{exprs};
  $node->{body} = [@body];
  $node->{type} = 'fn';
  $node;
}

# (macro (PARAM ...) BODY)
sub run_macro {
  my $node = run_lambda(@_);
  $node->{macro} = 1;
  $node;
};

# 'EXPR
sub run_quote {
  my ($runtime, $scope, $node) = @_;
  return $node->{expr};
}

sub run_fn {
  my ($runtime, $scope, $node) = @_;
  $node;
}

sub run_primitive_fn {
  my ($runtime, $scope, $node) = @_;
  $node;
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
  my $runtime = bless {nodes => shift, export => {}};
  my $scope = root_scope;
  my @results = evaluate_nodes($runtime, $scope, $runtime->{nodes});
  # only return the last result
  return { value => $results[-1], export => $runtime->{export} };
}

1;
