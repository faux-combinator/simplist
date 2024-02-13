use Modern::Perl;
use Test::More;
use Test::Fatal;
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
use Data::Dump qw(pp);

sub check {
  my $code = shift;
  $code =~ s/\n//g; # lol newlines not handled
  my @tokens = lex($code);
  my $parsetree = parse(\@tokens);
  evaluate($parsetree)
}

sub run {
  check(shift)->{value};
}

is_deeply run('
(import std (list list/length))
(list/length (list 1 2 3 2 1))
'), {type => 'num', value => 5},
  "list/length";

is_deeply run('
(import std (list list/at +))
(+
  (list/at (list 1 2 3 2 100) 0)
  (list/at (list 1 2 3 2 100) 4))
'), {type => 'num', value => 101},
  "list/at";

like(exception { run('(import std (list list/at +)) (list/at (list) 0)') },
  qr/Index 0 is out of bounds for array of size 0/,
  "OOB");

like(exception { run('(import std (list list/at +)) (list/at (list) -1)') },
  qr/Index -1 is out of bounds for array of size 0/,
  "OOB");

is_deeply run("
(import std (list list/at list/length +))
(let lst '(1 2 3 100)
  (list/at lst (+ (list/length lst) -1)))
"), {type => 'num', value => 100},
  "list/last kinda";

is_deeply run('
(import std (+))
(def last (lambda () 1))
(+ (last)
   (last))
'), {type => 'num', value => 2},
  "def lambda";

is_deeply run('
(def id (lambda (x) x))
(id 100)
'), {type => 'num', value => 100},
  "def id";

is_deeply run('
(import std (list list/at))
(def fst
  (lambda (xs)
    (list/at xs 0)))
(fst (list 1 2 3))
'), {type => 'num', value => 1},
  "def fst";

is_deeply run('
(import std (list list/at list/length))
(def len
  (lambda (xs)
    (list/length xs)))
(len (list 1 2 3))
'), {type => 'num', value => 3},
  "def len";

is_deeply run('
(import std (+ list list/at list/length))
(def lst-idx
  (lambda (xs)
    (+ (list/length xs) -1)))
(lst-idx (list 1 2 3))
'), {type => 'num', value => 2},
  "def lst-idx";

is_deeply run('
(import std (+ list list/at list/length))
(def lst-idx
  (lambda (xs)
    (let calc (+ (list/length xs) -1)
      calc)))
(lst-idx (list 1 2 3))
'), {type => 'num', value => 2},
  "def lst-idx in let";

is_deeply run('
(import std (+ list list/at list/length))
(def last
  (lambda (xs)
    (let calc (+ (list/length xs) -1)
      (list/at xs calc))))
(last (list 1 2 100))
'), {type => 'num', value => 100},
  "def lst-idx in let";

is_deeply run('
(import std (+))
(let thrice
  (lambda (x) (+ x x x))
  (+ (thrice 1) (thrice 3)))
'), {type => 'num', value => 12},
  "multicast";

is_deeply run('
(import std (+ list list/at list/length))
(def last
  (lambda (xs)
    (let last-idx (+ (list/length xs) -1)
      (list/at xs last-idx))))
(+
  (last (list 1 2 3 2 100))
  (last (list 1 2 3 2 1000))
)
'), {type => 'num', value => 1100},
  "def/last/let/length etc interacting";

done_testing;
