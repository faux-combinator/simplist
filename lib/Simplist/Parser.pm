package Simplist::Parser;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use FauxCombinator::Parser;
use Data::Dump qw(pp);

@EXPORT_OK = qw(parse);

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
  $parser->expect('lparen');
  my $exprs = $parser->any_of(\&expr);
  $parser->expect('rparen');
  {type => 'list', exprs => $exprs}
}

sub quote {
  my $parser = shift;
  $parser->expect('quote');
  my $expr = $parser->match(\&expr);

  {type => 'quote', expr => $expr}
}

sub expr {
  shift->one_of(\&quote, \&call, \&literal);
}

sub parse {
  my $parser = FauxCombinator::Parser::new(shift);
  $parser->many_of(\&expr);
}

1;
