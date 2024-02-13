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
  [ qr{[a-z+*/-][a-z0-9+*/-]*}, 'id' ],
);

sub lex {
  my $code = shift;
  chomp $code;
  return FauxCombinator::Lexer::lex(\@rules, $code);
}

1;
