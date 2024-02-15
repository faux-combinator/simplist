use Modern::Perl;
use Test::More;
use Test::Fatal;
use Data::Dump qw(pp);
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
#BEGIN { plan tests => 8; }
my $lib_path = 't/lib/';

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

sub exported {
  check(shift)->{export};
}

is_deeply run('1'), {type => 'num', value => 1},
  "Basic test";
is_deeply run('(import std (+)) (+)'), {type => 'num', value => 0},
  "Empty call";
is_deeply run('(import std (+)) (+ 1)'), {type => 'num', value => 1},
  "One-value call";
is_deeply run('(import std (+)) (+ 1 2 3)'), {type => 'num', value => 6},
  "Multi-values call";

# TODO ensure let allows to redefine primitives
is_deeply run('(let a 3 a)'), {type => 'num', value => 3},
  "Let";
is_deeply run('(let a 3 (let b 4 a))'), {type => 'num', value => 3},
  "Let over Let";
is_deeply run('(let a 3 (let a 4 a))'), {type => 'num', value => 4},
  "Let over Let (same name)";
is_deeply run('(import std (+)) (let a 3 (let b 4 (+ a b)))'), {type => 'num', value => 7},
  "Let over Let, with body";

is_deeply run('(let id (lambda (x) x) (id 4))'), {type => 'num', value => 4},
  "Lambda in Let";
is_deeply run('((lambda (x) (import std (+)) (+ 1 x)) 4)'), {type => 'num', value => 5},
  "Lambda as value";

is_deeply run('
((lambda ()
  1
  2
  3))
'), {type => 'num', value => 3},
  "Multiple exprs in let body";

is_deeply run('
(import std (+))
((let val 3
  (lambda (x) (+ val x)))
  4)
'), {type => 'num', value => 7},
  "Let over lambda";

is_deeply run('
((let val 10
  (let val 3
    (lambda (x)
      (import std (+))
      (+ val x))))
  4)
'), {type => 'num', value => 7},
  "Let over lambda";

is_deeply run('
(let x 3
  (let fn (lambda (x) x)
    (fn 7)))
'), {type => 'num', value => 7},
  "Let over lambda - lambda params take over lexical scope";

is_deeply run('
(let fn (lambda (x) x)
  (let x 3 (fn 7)))
'), {type => 'num', value => 7},
  "Let over lambda - lambda params take over dynamic scope";

is_deeply run('((lambda (x) (let x 3 x)) 7)'), {type => 'num', value => 3},
  "Let over lambda - let in lambda take over let params";

is_deeply run('(import std (list)) (list 1 2)'), {
  type => 'list',
  exprs => [
    {type => 'num', value => 1},
    {type => 'num', value => 2},
  ]}, "A list";

is_deeply run('(import std (+ list)) (list 4 (+ 1 2))'), {
  type => 'list',
  exprs => [
    {type => 'num', value => 4},
    {type => 'num', value => 3},
  ]}, "A list, correct evaluation context";

{
  my $deep_list = {
    type => 'list',
    exprs => [
      {type => 'num', value => 1},
      {type => 'list', exprs => [
          {type => 'num', value => 2},
          {type => 'list', exprs => [
              {type => 'num', value => 3},
  ]}]}]};

  is_deeply run('(import std (list)) (list 1 (list 2 (list 3)))'), $deep_list, "A list";
  is_deeply run("'(1 (2 (3)))"), $deep_list, "A list";
}

# TODO test empty lists
{
  my $result = run('(import std (list +)) (list + 2 (+ 2 1))');
  is $result->{type}, 'list', "It's a list";
  is scalar @{$result->{exprs}}, 3, "with 3 parts";
  is $result->{exprs}[0]{type}, 'primitive_fn', "first is a primitive_fn";
  is_deeply $result->{exprs}[1], {type => 'num', value => 2}, "second is 2";
  is_deeply $result->{exprs}[2], {type => 'num', value => 3}, "third is 3";
}

is_deeply run('(import std (list +)) (eval \'(+ 1 2))'), {type => 'num', value => 3},
  "Eval works";

is_deeply run("(import std (+)) ((eval '+))"), {type => 'num', value => 0},
  "Eval resolves quoted stuff";

is_deeply run("(import std (+)) (eval (eval (eval +)))")->{type}, "primitive_fn",
  "A primitive function evaluates to itself";

is_deeply run("(eval (eval (eval (lambda () 1))))")->{type}, "fn",
  "A primite function evaluates to itself";

is_deeply run("(import std (+)) ((eval (eval ''+)))"), {type => 'num', value => 0},
  "Eval resolves quoted stuff... twice";

is_deeply run("(import std (+)) (eval '(+ 1 (+ 2 3)))"), {type => 'num', value => 6},
  "Eval works at every level";

is_deeply run("(import std (list +)) (eval '(list 1 '(+ 1 2)))"), {
  type => 'list', exprs => [
    {type => 'num', value => 1},
    {type => 'list', exprs => [
        {type => 'id', value => '+'},
        {type => 'num', value => 1},
        {type => 'num', value => 2},
] } ] }, "Quote in quote works";

is_deeply run("''+"), {type => 'quote', expr => {type => 'id', value => '+'}},
  "Quote will wrap and wrap";

is_deeply run("
(import std (+))
((let fn
  (let + (lambda () 15) '+)
  (eval fn))
 3)
"), {type => 'num', value => 3},
  "Quoting an identifier delays its resolution";

is_deeply run("
(let fn (lambda (id x y) (import std (+)) (+ y (eval id)))
  (let x 10
    (fn 'x 5 x)))
"), {type => 'num', value => 15},
  "Quoting in function context";

is_deeply run("
(let m (macro () 'value)
  (let value 10
    (m)))
"), {type => 'num', value => 10},
  "MACROS (macro's return value is evaluated in the calling scope)";

is_deeply run("
(import std (+))
(let mylet (macro (name value body)
              (import std (list))
              (list (list 'lambda (list name) body) value))
  (mylet a 5 (+ 3 a)))
"), {type => 'num', value => 8},
  "Macros can be used to reimplement let";

is_deeply run("
(import std (+))
(let m (let name 'id
          (macro (value body)
            (import std (list))
            (list 'let name value body)))
  (m 3 (+ id id)))
"), {type => 'num', value => 6},
  "macros are evaluated in their lexical scope";

is_deeply run("
(let m (let id 5
          (macro (name)
            (eval name)))
  (m id))
"), {type => 'num', value => 5},
  "macros can eval their arguments";

is_deeply run("
(let m
  (let id 'x
    (macro (name)
      (eval name)))
  (let x 3 (m id)))
"), {type => 'num', value => 3},
  "macros respect both scopes at the same time";

is_deeply run("
(import std (+ list))
(let outer
  (macro ()
    (list 'macro (list) (list '+ 3 4)))
  ((outer)))
"), {type => 'num', value => 7},
  "macros can be returned from macros";

is_deeply run("1 2 3"), {type => 'num', value => 3},
  "can have multiple statements";

like(exception { run('()'); }, qr/invalid call/,
  "Empty calls are invalid");

is_deeply run('(def a 1) (def b 2) (import std (+)) (+ a b)'),
  {type => 'num', value => 3},
  'def values';
# TODO error: `(def)`
# TODO error: `(def a)`
# TODO error: `(def a b foobar)`
# TODO error: `(def (not-an-id) 1)`
# TODO error: def nested in lambda etc

is_deeply check("(export a 1)"), {
  value => {type => 'num', value => 1},
  export => {a => {type => 'num', value => 1}}
}, "export returns its value";

is_deeply check("(import std (+)) (export a 1) (export b (+ a 1)) (+ a b)"), {
  value => {type => 'num', value => 3},
  export => {
    a => {type => 'num', value => 1},
    b => {type => 'num', value => 2}
  }
}, "export also exposes the names";

like(exception { run('((lambda () (export a 1)))') }, qr/top-level/,
  "Cannot have an export inside ane expr");



# XXX allow export in `let`s 
#is_deeply check("(let start 1 (export a start) (export b start))"), {
#  value => {type => 'num', value => 1},
#  export => {
#    a => {type => 'num', value => 1},
#    b => {type => 'num', value => 1}
#  }
#}, "export available in let";

like(exception { run('(let x ((lambda () (import std (+)) (+ 1 2))) (+ x x))') },
  qr/no such identifier: \+/,
  "imports are local");

like(exception { run('(let m (macro () (import std (list)) \'(list 1 2)) (m))') },
  qr/no such identifier: list/,
  "imports don't cross macro phases");

like(exception { run('(import std (abcdef))') },
  qr/Package std has no abcdef/,
  "Cannot import variables that don't exist");

# XXX import-as

like(exception { run('(import x ())') },
  qr/Cannot import without a defined SIMPLIST_PATH/,
  "requires SIMPLIST_PATH to load");

{
  local $ENV{SIMPLIST_PATH} = $lib_path;
  is_deeply run("
(import mylib (a b add3))
(import std (+))
(add3 (+ a b))
"), { type => 'num', value => 6 }, "Can import a library!";

  like(exception { run('(import mylib (a b)) (+ a b)') },
    qr/no such identifier: \+/,
    "Import doesn't pollute the current scope");
}

{
  use Capture::Tiny ':all';
  my $stdout = capture_stdout(sub {
    is_deeply run("(import std (say)) (say 1 2 3)"),
      {type => 'list', exprs => []},
      "Say returns an empty list";
  });
  is $stdout, "1\n2\n3\n", "`say` works";
}

{
  use Capture::Tiny ':all';
  local $ENV{SIMPLIST_PATH} = $lib_path;
  my $stdout = capture_stdout(sub {
    is_deeply run("(import printmod (a)) (import printmod (a)) (import printmod (a))"),
      {type => 'list', exprs => []},
      "Say returns an empty list";
  });
  is $stdout, "123\n", "module only loads once";
}

{
  local $ENV{SIMPLIST_PATH} = $lib_path;
  is_deeply run("(import with (with-it)) (with-it 5 it)"),
    {type => 'num', value => 5},
    "Import macro";
}

done_testing;
