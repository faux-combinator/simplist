package Simplist::Lexer;
use Modern::Perl;
use Exporter 'import';
use vars qw(@EXPORT_OK);
use Lexer;

@EXPORT_OK = qw(lex);

my @rules = (
  [ qr/\(/, 'lparen' ],
  [ qr/\)/, 'rparen' ],
  [ qr/[0-9]+/, 'num' ],
  [ qr{[+*/-]+}, 'op' ],
  [ qr/[a-z]+/, 'id' ] 
);

sub lex {
  return Lexer::lex(\@rules, shift);
}
