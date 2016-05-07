package Simplist::Eval;
use Modern::Perl;
use Exporter qw(import);
use List::Util qw(sum);
use Data::Dump qw(pp);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(evaluate);

sub evaluate {
  my $runtime = bless {nodes => shift};
  evaluate_nodes($runtime, $runtime->{nodes});
}

sub evaluate_nodes {
  my ($runtime, $nodes) = @_;
  my @values;
  while (my $node = shift @{$nodes}) {
    my $method = "run_$node->{type}";
    # TODO pass scope or some other stuff
    push @values, $runtime->$method($node);
  }
  @values
}

sub add {
  sum @_
};

sub run_call {
  my ($runtime, $node) = @_;
  my $function = shift @{$node->{exprs}};
  my @values = evaluate_nodes $runtime, $node->{exprs};

  add @values;
};

sub run_num {
  my ($runtime, $node) = @_;
  $node->{value};
};

sub run_id {
  die 'scopes NYI, sorry';
}
