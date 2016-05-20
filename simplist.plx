#!/usr/bin/env perl
use Modern::Perl;
use Data::Dump qw(pp);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use Simplist::Parser qw(parse);
use Simplist::Lexer qw(lex);
use Simplist::Eval qw(evaluate);

#my $parser = Simplist::Parser::new(<>);
#$parser->print();
my $code = "
(+ 1 0
  (* 2 3)
  (let value 3
    (+ value
      (let value
        (* 10 10)
        value)
      value)))";
$code =~ s/\n//g; # lol newlines not handled
#my $code = "(* 3 (let let 3 '(1 let 3)) 2)";
my @tokens = lex($code);
pp(@tokens);
my $parsetree = parse(\@tokens);
pp($parsetree);
pp(evaluate([$parsetree])); # TODO make parse return a list
