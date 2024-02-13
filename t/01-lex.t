use Modern::Perl;
use Test::More;
use Simplist::Lexer qw(lex);
BEGIN { plan tests => 11; }

is_deeply [lex('')], [], "Empty parse";
is_deeply [lex('(')], [{type => 'lparen', value => '('}], "Left parenthesis";
is_deeply [lex(')')], [{type => 'rparen', value => ')'}], "Right parenthesis";
is_deeply [lex("'")], [{type => 'quote', value => "'"}], "Quote";


is_deeply [lex("a")], [{type => 'id', value => 'a'}], "Identifier #1";
is_deeply [lex("abc")], [{type => 'id', value => 'abc'}], "Identifier #2";
is_deeply [lex("v/e+r-ycomplex*identifierz*")], [{type => 'id', value => 'v/e+r-ycomplex*identifierz*'}], "Identifier #3";

is_deeply [lex("1")], [{type => 'num', value => 1}], "Num #1";
is_deeply [lex("123")], [{type => 'num', value => 123}], "Num #2";
is_deeply [lex("1 2 3")], [{type => 'num', value => 1}, {type => 'num', value => 2}, {type => 'num', value => 3}], "Multinum";

is_deeply [lex("(add-+ 1 '(2))")], [
  {type => 'lparen', value => '('},
  {type => 'id', value => 'add-+'},
  {type => 'num', value => '1'},
  {type => 'quote', value => "'"},
  {type => 'lparen', value => '('},
  {type => 'num', value => '2'},
  {type => 'rparen', value => ')'},
  {type => 'rparen', value => ')'},
], "Num #1";
