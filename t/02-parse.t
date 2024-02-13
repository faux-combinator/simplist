use Modern::Perl;
use Test::More;
use Test::Fatal;
use Simplist::Parser qw(parse);
BEGIN { plan tests => 14; }

my $lparen = {type => 'lparen', value => '('};
my $rparen = {type => 'rparen', value => ')'};
my $quote = {type => 'quote', value => "'"};
my $num = {type => 'num', value => 1};
my $id = {type => 'id', value => 'abc'};
my $empty_list = {type => 'list', exprs => []};

is_deeply parse([$num]), [$num],
  "Simple num parse";
is_deeply parse([$id]), [$id],
  "Simple num parse";

is_deeply parse([$num, $id, $num]), [$num, $id, $num],
  "Multi-pa(r)se";

is_deeply parse([$lparen, $rparen]), [$empty_list],
  "Empty call";
is_deeply parse([$lparen, $id, $rparen]), [
  {type => 'list', exprs => [$id]}
], "One-value call";
is_deeply parse([$lparen, $id, $num, $num, $rparen]), [
  {type => 'list', exprs => [$id, $num, $num]}
], "Multi-values call";

is_deeply parse([$quote, $lparen, $rparen]), [
  {type => 'quote', expr => $empty_list},
], "Empty list";

is_deeply parse([$quote, $lparen, $num, $rparen]), [
  { type => 'quote', expr => {
      type => 'list',
      exprs => [$num],
    } },
], "One value list";

is_deeply parse([$quote, $lparen, $num, $id, $num, $rparen]), [
  { type => 'quote', expr => {
      type => 'list',
      exprs => [$num, $id, $num],
    } },
], "Multi value list";

is_deeply parse([$num, $num, $num]), [
  { type => 'num', value => 1 },
  { type => 'num', value => 1 },
  { type => 'num', value => 1 }
], "Multi expressions";

like(exception { is_deeply parse([]), []; }, qr/one_of/,
  "fails to parse the one_of");
like(exception { is_deeply parse([$quote]), []; }, qr/one_of/,
  "fails to parse the one_of");
# note: these fails on one_of, because the parser backtracks after "call" failed to parse
like(exception { is_deeply parse([$lparen]), []; }, qr/one_of/,
  "fails to parse the one_of");
like(exception { is_deeply parse([$rparen]), []; }, qr/one_of/,
  "fails to parse the one_of");
