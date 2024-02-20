use Modern::Perl;
use Test::More;
use Test::Fatal;
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
use Data::Dump qw(pp);

sub check {
  my $code = shift;
  my @tokens = lex($code);
  my $parsetree = parse(\@tokens);
  evaluate($parsetree)
}

sub run {
  check(shift)->{value};
}

like(exception { run(',1'); }, qr/unquote outside of a quasiquote/,
  "Cannot bare unquote");

like(exception { run(',@1'); }, qr/unquote-splicing outside of a quasiquote/,
  "Cannot bare unquote-splicing");

is_deeply run('`,1'), {type => 'num', value => 1},
  "quote-unquote";

is_deeply run('(let a 1 `,a)'), {type => 'num', value => 1},
  "unquote a variable";

is_deeply run('(import std (list)) (let a 1 `(list ,a))'), {
  type => 'list', exprs => [
    { type => 'id', value => 'list' },
    { type => 'num', value => 1 }
  ]
}, "unquote a variable in a list";

is_deeply run('(import std (list)) (eval (let a 1 `(list ,a)))'), {
  type => 'list', exprs => [
    { type => 'num', value => 1 }
  ]
}, "eval unquote";

is_deeply run('(import std (list)) (let trilist (macro (x) `(list ,x ,x ,x)) (trilist 1))'), {
  type => 'list', exprs => [
    { type => 'num', value => 1 },
    { type => 'num', value => 1 },
    { type => 'num', value => 1 },
  ]
}, "quasiquote in macro";

is_deeply run('
(let do
  (macro (body)
    `((lambda () ,@body)))
  (do (1 2 3 2 1)))'), {
  type => 'num', value => 1,
}, "unquote-splicing";


{
  use Capture::Tiny ':all';
  my $stdout = capture_stdout(sub {
    is_deeply run('
(import std (say +))
(let mylet
  (macro (name value body)
    `(let ,name ,value ((lambda () ,@body))))
  (mylet a 1
    ((say (+ a -1))
     (say a)
     (say (+ a 1))
     a)))
'), { type => 'num', value => 1, },
    "unquote, unquote-splicing";
  });
  is $stdout, "0\n1\n2\n", "elements were printed";
}

like(exception { run('`,@1'); }, qr/unquote-splicing outside of a list quasiquote/,
  "Cannot bare unquote-splicing");

done_testing;