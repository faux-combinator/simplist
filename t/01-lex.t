use Modern::Perl;
use Test::More;
use Simplist::Lexer qw(lex);
use helper;
BEGIN { plan tests => 12; }

my $lparen = tok('lparen', '(');
my $rparen = tok('rparen', ')');
my $quote = tok('quote', "'");
sub num {
  my ($n, $l, $c) = @_;
  tok('num', $n)->($l, $c);
}
sub id {
  my ($n, $l, $c) = @_;
  tok('id', $n)->($l, $c);
}

is_deeply [lex('')], [], "Empty parse";
is_deeply [lex('(')], [$lparen->(1, 0)], "Left parenthesis";
is_deeply [lex(')')], [$rparen->(1, 0)], "Right parenthesis";
is_deeply [lex("'")], [$quote->(1, 0)], "Quote";


is_deeply [lex("a")], [id('a', 1, 0)], "Identifier #1";
is_deeply [lex("abc")], [id('abc', 1, 0)], "Identifier #2";
is_deeply [lex("v/e+r-ycomplex*identifierz*")], [id('v/e+r-ycomplex*identifierz*', 1, 0)], "Identifier #3";

is_deeply [lex("1")], [num(1, 1, 0)], "Num #1";
is_deeply [lex("123")], [num(123, 1, 0)], "Num #2";
is_deeply [lex("1 5 9")], [num(1, 1, 0), num(5, 1, 2), num(9, 1, 4)], "Multinum";

is_deeply [lex("(add-+ 1\n  '(2))")], [
  tok('lparen', '(')->(1, 0),
  tok('id', 'add-+')->(1, 1),
  tok('num', '1')->(1, 7),
  tok('quote', "'")->(2, 2),
  tok('lparen', '(')->(2, 3),
  tok('num', '2')->(2, 4),
  tok('rparen', ')')->(2, 5),
  tok('rparen', ')')->(2, 6),
], "Complex expr";

is_deeply [lex("(list `1 `,1\n\n\n  `,@(list))")], [
  tok('lparen', '(')->(1, 0),
  tok('id', 'list')->(1, 1),
  tok('quasiquote', '`')->(1, 6),
  tok('num', '1')->(1, 7),
  tok('quasiquote', '`')->(1, 9),
  tok('unquote', ',')->(1, 10),
  tok('num', '1')->(1, 11),
  tok('quasiquote', '`')->(4, 2),
  tok('unquote_splicing', ',@')->(4, 3),
  tok('lparen', '(')->(4, 5),
  tok('id', 'list')->(4, 6),
  tok('rparen', ')')->(4, 10),
  tok('rparen', ')')->(4, 11),
], "Unquote and stuff";
