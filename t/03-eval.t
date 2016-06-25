use Modern::Perl;
use Test::More;
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
#BEGIN { plan tests => 8; }

sub run {
  my $code = shift;
  $code =~ s/\n//g; # lol newlines not handled
  my @tokens = lex($code);
  my $parsetree = parse(\@tokens);
  evaluate($parsetree);
}

is_deeply run('1'), {type => 'num', value => 1},
  "Basic test";
is_deeply run('(+)'), {type => 'num', value => 0},
  "Empty call";
is_deeply run('(+ 1)'), {type => 'num', value => 1},
  "One-value call";
is_deeply run('(+ 1 2 3)'), {type => 'num', value => 6},
  "Multi-values call";

is_deeply run('(let a 3 a)'), {type => 'num', value => 3},
  "Let";
is_deeply run('(let a 3 (let b 4 a))'), {type => 'num', value => 3},
  "Let over Let";
is_deeply run('(let a 3 (let b 4 (+ a b)))'), {type => 'num', value => 7},
  "Let over Let, with body";

is_deeply run('(let id (lambda (x) x) (id 4))'), {type => 'num', value => 4},
  "Lambda in Let";
is_deeply run('((lambda (x) (+ 1 x)) 4)'), {type => 'num', value => 5},
  "Lambda as value";

is_deeply run('
((let val 3
  (lambda (x) (+ val x)))
  4)
'), {type => 'num', value => 7},
  "Lambda as value";

done_testing;
