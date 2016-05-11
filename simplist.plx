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
#my @tokens = lex("(+ (* 2 3) a (length '(1 2 3)))");
my @tokens = lex("(+ 1 0 (* 2 3) ten)");
pp(@tokens);
my $parsetree = parse(\@tokens);
pp($parsetree);
pp(evaluate([$parsetree])); # TODO make parse return a list
