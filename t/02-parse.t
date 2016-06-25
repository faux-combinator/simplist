use Modern::Perl;
use Test::More;
use Test::Fatal;
use Simplist::Parser qw(parse);
BEGIN { plan tests => 11; }

my $lparen = {type => 'lparen', value => '('};
my $rparen = {type => 'rparen', value => ')'};
my $quote = {type => 'quote', value => "'"};
my $num = {type => 'num', value => 1};
my $id = {type => 'id', value => 'abc'};

is_deeply parse([$num]), [$num], "Simple num parse";
is_deeply parse([$id]), [$id], "Simple num parse";

is_deeply parse([$num, $id, $num]), [$num, $id, $num], "Multi-pa(r)se";

#should fail: is_deeply parse([$lparen, $rparen]), [], "Empty call";

is_deeply parse([$quote, $lparen, $rparen]), [
  {type => 'call', exprs => [
      {type => 'id', value => 'quote'},
  ]},
], "Empty list";

is_deeply parse([$quote, $lparen, $rparen]), [
  {type => 'call', exprs => [
      {type => 'id', value => 'quote'},
  ]},
], "No value list";

is_deeply parse([$quote, $lparen, $num, $rparen]), [
  {type => 'call', exprs => [
      {type => 'id', value => 'quote'},
      $num,
  ]},
], "One value list";

is_deeply parse([$quote, $lparen, $num, $id, $num, $rparen]), [
  {type => 'call', exprs => [
      {type => 'id', value => 'quote'},
      $num,
      $id,
      $num,
  ]},
], "One value list";

like(exception { is_deeply parse([]), []; }, qr/one_of/, "fails to parse the one_of");
like(exception { is_deeply parse([$quote]), []; }, qr/one_of/, "fails to parse the one_of");
# note: these fails on one_of, because the parser backtracks after "call" failed to parse
like(exception { is_deeply parse([$lparen]), []; }, qr/one_of/, "fails to parse the one_of");
like(exception { is_deeply parse([$rparen]), []; }, qr/one_of/, "fails to parse the one_of");
