package Simplist::Parser;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use FauxCombinator::Parser;
use Data::Dump qw(pp);

@EXPORT_OK = qw(parse);

sub _with_loc {
  my ($node, $start, $end) = @_;
  $node->{start} = $start->{start} if $start and exists $start->{start};
  $node->{end} = $end->{end} if $end and exists $end->{end};
  $node
}

sub num {
  shift->expect('num');
}

sub id {
  shift->expect('id');
}

sub literal {
  shift->one_of(\&num, \&id);
}

sub call {
  my $parser = shift;
  my $l = $parser->expect('lparen');
  my $exprs = $parser->any_of(\&expr);
  my $r = $parser->expect('rparen');
  _with_loc {
    type => 'list',
    exprs => $exprs,
  }, $l, $r;
}

sub quote_unquote_token {
  my $parser = shift;
  $parser->one_of(
    sub { $parser->expect('quote') },
    sub { $parser->expect('quasiquote') },
    sub { $parser->expect('unquote') },
    sub { $parser->expect('unquote_splicing') },
  );
}

sub quote {
  my $parser = shift;
  my $quote = $parser->match(\&quote_unquote_token);
  my $expr = $parser->match(\&expr);

  _with_loc {
    type => $quote->{type},
    expr => $expr,
  }, $quote, $quote;
}

sub expr {
  shift->one_of(\&quote, \&call, \&literal);
}

sub parse {
  my $parser = FauxCombinator::Parser::new(shift);
  $parser->many_of(\&expr);
}

1;
