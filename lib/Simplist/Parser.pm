package Simplist::Parser;
use Modern::Perl;
use Exporter qw(import);
use vars qw(@EXPORT_OK);
use FauxCombinator::Parser;

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

sub expr {
  shift->one_of(\&lst, \&literal);
}

sub lst {
  my $parser = shift;
  $parser->expect('lparen');
  my $exprs = $parser->many_of(\&expr);
  $parser->expect('rparen');
  $exprs
}

sub parse {
  my $parser = FauxCombinator::Parser::new(shift);
  $parser->match(\&expr);
}

1;
