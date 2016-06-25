package Simplist::Lexer;
use Modern::Perl;
use Exporter 'import';
use vars qw(@EXPORT_OK);
use FauxCombinator::Lexer;

@EXPORT_OK = qw(lex);

my @rules = (
  [ qr/\(/, 'lparen' ],
  [ qr/\)/, 'rparen' ],
  [ qr/'/, 'quote' ],
  [ qr/\d+/, 'num' ],
  [ qr{[a-z+*/-]+}, 'id' ],
);

sub lex {
  return FauxCombinator::Lexer::lex(\@rules, shift);
}

1;
