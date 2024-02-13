use Modern::Perl;
use Test::More;
use Test::Fatal;
use Data::Dump qw(pp);
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
#BEGIN { plan tests => 8; }

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
is_deeply run('(+)'), {type => 'num', value => 0},
  "Empty call";
is_deeply run('(+ 1)'), {type => 'num', value => 1},
  "One-value call";
is_deeply run('(+ 1 2 3)'), {type => 'num', value => 6},
  "Multi-values call";

# TODO ensure let allows to redefine primitives
is_deeply run('(let a 3 a)'), {type => 'num', value => 3},
  "Let";
is_deeply run('(let a 3 (let b 4 a))'), {type => 'num', value => 3},
  "Let over Let";
is_deeply run('(let a 3 (let a 4 a))'), {type => 'num', value => 4},
  "Let over Let (same name)";
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
  "Let over lambda";

is_deeply run('
((let val 10
  (let val 3
    (lambda (x) (+ val x))))
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

is_deeply run('(list 1 2)'), {
  type => 'list',
  exprs => [
    {type => 'num', value => 1},
    {type => 'num', value => 2},
  ]}, "A list";

is_deeply run('(list 4 (+ 1 2))'), {
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

  is_deeply run('(list 1 (list 2 (list 3)))'), $deep_list, "A list";
  is_deeply run("'(1 (2 (3)))"), $deep_list, "A list";
}

# TODO test empty lists
{
  my $result = run('(list + 2 (+ 2 1))');
  # remove the "CODE" part of the sub
  undef $result->{exprs}[0]->{value};
  is_deeply $result, {type => 'list', exprs => [
      {type => 'primitive_fn', value => undef},
      {type => 'num', value => 2},
      {type => 'num', value => 3},
    ]}, "Lists";
}

is_deeply run('(eval (list + 1 2))'), {type => 'num', value => 3},
  "Eval works";

is_deeply run("((eval '+))"), {type => 'num', value => 0},
  "Eval resolves quoted stuff";

is_deeply run("(eval (eval (eval +)))")->{type}, "primitive_fn",
  "A primitive function evaluates to itself";

is_deeply run("(eval (eval (eval (lambda () 1))))")->{type}, "fn",
  "A primite function evaluates to itself";

is_deeply run("((eval (eval ''+)))"), {type => 'num', value => 0},
  "Eval resolves quoted stuff... twice";

is_deeply run("(eval '(+ 1 (+ 2 3)))"), {type => 'num', value => 6},
  "Eval works at every level";

is_deeply run("(eval '(list 1 '(+ 1 2)))"), {
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
((let fn
  (let + (lambda () 15) '+)
  (eval fn))
 3)
"), {type => 'num', value => 3},
  "Quoting an identifier delays its resolution";

is_deeply run("
(let fn (lambda (id x y) (+ y (eval id)))
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
(let mylet (macro (name value body)
              (list (list 'lambda (list name) body) value))
  (mylet a 5 (+ 3 a)))
"), {type => 'num', value => 8},
  "Macros can be used to reimplement let";

is_deeply run("
(let m (let name 'id
          (macro (value body)
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

is_deeply check("(export a 1)"), {
  value => {type => 'num', value => 1},
  export => {a => {type => 'num', value => 1}}
}, "export returns its value";

is_deeply check("(export a 1) (export b (+ a 1)) (+ a b)"), {
  value => {type => 'num', value => 3},
  export => {
    a => {type => 'num', value => 1},
    b => {type => 'num', value => 2}
  }
}, "export also exposes the names";

like(exception { run('((lambda () (export a 1)))') }, qr/top-level/,
  "Cannot have an export inside ane expr");

#is_deeply check("(let start 1 (export a start) (export b start))"), {
#  value => {type => 'num', value => 1},
#  export => {
#    a => {type => 'num', value => 1},
#    b => {type => 'num', value => 1}
#  }
#}, "export available in let";

# TODO import

done_testing;
