#!/usr/bin/env perl
use Modern::Perl;
use Data::Dump qw(pp);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0) . '/lib';
use Simplist::Parser qw(parse);
use Simplist::Lexer qw(lex);

#my $parser = Simplist::Parser::new(<>);
#$parser->print();
pp lex("(+ 1 a)")