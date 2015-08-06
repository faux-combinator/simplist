package Lexer;
use Modern::Perl;
use Exporter 'import';
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(lex);

my $space = qr/[ \t]/;

sub lex {
  my @tokens;
  my ($rules, $code) = @_;
  part: while ($code) {
    $code =~ s/^$space+//;
    for (@$rules) {
      my ($regexp, $type, $mutate) = @$_;
      if ($code =~ /^($regexp)/) {
        push @tokens, {
          type => $type,
          value => $mutate ? $mutate->($1) : $1
        };
        $code = substr($code, length($1));
        next part;
      }
    }
    # TODO slice code not to be too big
    die "unable to match rule on this code: $code";
  }
  return \@tokens
}
