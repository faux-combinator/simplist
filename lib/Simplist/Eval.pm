package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Scope qw(root_scope);
use Simplist::Import qw(resolve_import);
use List::Util qw(any);
use Data::Dump qw(pp);

@EXPORT_OK = qw(evaluate);

my @specials = qw(let lambda eval macro export import def);

sub _unloc {
  my ($node) = @_;
  if (exists $node->{start} || exists $node->{end} || exists $node->{filename}) {
    my %un = %{$node};
    delete @un{"start", "end", "filename"};
    \%un
  } else {
    $node
  }
}

sub evaluate_node {
  my ($runtime, $scope, $node) = @_;
  my $method = "run_$node->{type}";
  _unloc $runtime->$method($scope, $node);
}

sub evaluate_nodes {
  my ($runtime, $scope, $nodes) = @_;
  map { evaluate_node($runtime, $scope, $_) } @$nodes;
}

sub is_special_call {
  my $fn = shift;
  $fn->{type} eq "id" && any { $_ eq $fn->{value} } @specials;
}

sub die_with {
  my ($message, $node) = @_;
  my ($start, $end);

  # Try to find the boundaries...
  if (exists $node->{start} and exists $node->{end}) {
    $start = $node->{start};
    $end = $node->{end};
  } elsif ($node->{type} eq 'list' && @{$node->{exprs}}) {
    my @exprs = @{$node->{exprs}};
    $start = $exprs[0]{start};
    $end = $exprs[-1]{end};
  }

  if (defined $start) {
    $message .= " at $start->{line}:$start->{column}";
    if (defined $end) {
      $message .= " - $end->{line}:$end->{column}";
    }
  }
  if (exists $node->{filename}) {
    $message .= " in $node->{filename}";
  }
  die $message
}

# (def NAME EXPR)
# TODO forbid (def NAME (def NAME ...))
sub run_def {
  my ($runtime, $scope, $node) = @_;
  die_with "def is only available at the top-level", $node if $scope->in_function;
  die_with "def needs a name and a value", $node unless @{$node->{exprs}} == 3;
  my ($_kw, $name, $value) = @{$node->{exprs}};
  die_with "def name should be a static identifier", $node unless $name->{type} eq 'id';
  my $result = evaluate_node($runtime, $scope, $value);
  $scope->assign($name->{value}, $result);
  $result
}

# (export NAME EXPR)
sub run_export {
  my ($runtime, $scope, $node) = @_;
  die_with "Export is only available at the top-level", $node if $scope->{parent};
  die_with "Export needs a name and a value", $node unless @{$node->{exprs}} == 3;
  my ($_kw, $name, $value) = @{$node->{exprs}};
  die_with "Exported name should be a static identifier", $node unless $name->{type} eq 'id';
  my $result = evaluate_node($runtime, $scope, $value);
  $scope->export($name->{value}, $result);
  $result # If it's the last statement
}

# helper used by importer to avoid cycle imports
sub _import_load {
  my ($code, $filename) = @_;
  my @tokens = lex($code);
  my $tree = parse(\@tokens);
  evaluate($tree, $filename)->{export}
}

# (import LIBNAME (NAME...))
sub run_import {
  my ($runtime, $scope, $node) = @_;
  die_with "NYI import-as", $node if @{$node->{exprs}} == 1;
  die_with "Malformed import statement", $node unless @{$node->{exprs}} == 3;
  my ($_kw, $pkg, $names) = @{$node->{exprs}};
  die_with "Exported name should be a static identifier", $node unless $pkg->{type} eq 'id';
  my $package = $pkg->{value};
  die_with "Import list should be a list", $node unless $names->{type} eq 'list';

  # Store imports in `modules` so we don't run their side-effects twice
  my $import = $runtime->{modules}{$package} //= resolve_import($package, \&_import_load);

  die_with "Cannot resolve module $package", $node unless $import;
  for my $name (@{$names->{exprs}}) {
    die_with "Import name should be an identifier", $name unless $name->{type} eq 'id';
    die_with "Package $package has no $name->{value}", $name unless exists $import->{$name->{value}};
    $scope->assign($name->{value}, $import->{$name->{value}});
  }

  # TODO return the object/import-as
  {type => 'list', exprs => []}
}

# (CALLABLE PARAM...)
# TODO cleanup this mess.
# extract the scope-resolve code
#  and probably the dispatch on fn/primitive_call
sub run_list {
  my ($runtime, $scope, $node) = @_;
  die_with "invalid call: empty call", $node unless @{$node->{exprs}};
  my @exprs = @{$node->{exprs}};
  my $fn = shift @exprs;
  if (is_special_call($fn)) {
    my $method = "run_$fn->{value}";
    return $runtime->$method($scope, $node);
  }

  $fn = evaluate_node($runtime, $scope, $fn);
  if ($fn->{macro}) {
    return $runtime->run_macro_call($scope, $fn, \@exprs);
  }
  my @values = evaluate_nodes($runtime, $scope, \@exprs);
  die_with "not callable: $fn->{type}", $fn unless $fn->{type} =~ /fn$/;

  if ($fn->{type} eq 'primitive_fn') {
    $fn->{value}(@values);
  } else {
    $runtime->run_lambda_call($scope, $fn, \@values, 'function');
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
  my ($runtime, $outer_scope, $fn, $values, $type) = @_;
  my $scope = $fn->{scope};
  my @param_names = @{$fn->{param_names}};

  my $new_scope = $scope->child($type);
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
  return $runtime->evaluate_node($outer_scope, run_lambda_call(@_, 'macro'));
}

# (let NAME VALUE EXPR)
sub run_let {
  my ($runtime, $scope, $node) = @_;
  my ($_kw, $name, $value, $expr) = @{$node->{exprs}};
  die_with "cannot let a non-id", $name unless $name->{type} eq "id";
  my $new_scope = $scope->child('let');
  $new_scope->assign($name->{value}, evaluate_node($runtime, $scope, $value));
  return evaluate_node($runtime, $new_scope, $expr);
}

# (eval EXPR)
sub run_eval {
  my ($runtime, $scope, $node) = @_;
  my @exprs = @{$node->{exprs}};
  shift @exprs; # Remove `eval`
  die_with "eval can only eval one thing", $node if @exprs != 1;
  
  my ($expr) = @exprs;
  my $result = evaluate_node($runtime, $scope, $expr);
  evaluate_node($runtime, $scope, $result);
};

# (lambda (PARAM ...) BODY)
sub run_lambda {
  my ($runtime, $scope, $node) = @_;
  # extract scope, parameters and body
  my @parts = @{$node->{exprs}};
  shift @parts; # remove `lambda`
  die_with 'invalid syntax to lambda', $node if scalar @parts < 2;

  # the first () is the params, the 2nd is the body
  my ($params, @body) = @parts;

  my @params = @{$params->{exprs}};
  for my $param (@params) {
    die_with 'parameters must be identifiers', $param unless $param->{type} eq 'id';
  }
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
  $node
}

sub run_id {
  my ($runtime, $scope, $node) = @_;
  my $value = $scope->resolve($node->{value});
  die_with "no such identifier: $node->{value}", $node unless $value;
  $value;
}

sub quasiquote {
  my ($runtime, $scope, $depth, $expr) = @_;
  if ($expr->{type} eq 'unquote_splicing') {
    die_with 'unquote-splicing outside of a list quasiquote', $expr;
  } elsif ($expr->{type} eq 'unquote') {
    if ($depth == 0) {
      evaluate_node($runtime, $scope, $expr->{expr});
    } else {
      {type => 'unquote', expr => quasiquote($runtime, $scope, $depth - 1, $expr->{expr})};
    }
  } elsif ($expr->{type} eq 'list') {
    my @mapped = map {
      if ($_->{type} eq 'unquote_splicing') {
        if ($depth == 0) {
          my $result = evaluate_node($runtime, $scope, $_->{expr});
          # Our model is a bit convoluted, so we need this...
          die 'Unquote-splicing didn\'t result in a list' unless $result->{type} eq 'list';
          @{$result->{exprs}}
        } else {
          # XXX this should "distribute" over the multiple elements, not sure here or not...
          die "NYI nested unquote_splicing";
          {type => 'unquote_splicing', expr => quasiquote($runtime, $scope, $depth - 1, $_->{expr})};
        }
      } else {
        _unloc quasiquote($runtime, $scope, $depth, $_)
      }
    } @{$expr->{exprs}};
    {type => 'list', exprs => [@mapped]}
  } elsif ($expr->{type} eq 'quote') {
    {type => 'quote', expr => _unloc quasiquote($runtime, $scope, $depth, $expr->{expr})};
  } elsif ($expr->{type} eq 'quasiquote') {
    {type => 'quasiquote', expr => _unloc quasiquote($runtime, $scope, $depth + 1, $expr->{expr})};
  } else {
    $expr
  }
}
sub run_quasiquote {
  my ($runtime, $scope, $node) = @_;
  quasiquote($runtime, $scope, 0, $node->{expr});
}

sub run_unquote {
  die 'unquote outside of a quasiquote';
}

sub run_unquote_splicing {
  die 'unquote-splicing outside of a quasiquote';
}

sub evaluate {
  my $nodes = shift;
  my $runtime = bless {modules => {}};
  my $scope = root_scope;
  my @results = evaluate_nodes($runtime, $scope, $nodes);
  # only return the last result
  return { value => $results[-1], export => $scope->{export} };
}

1;
