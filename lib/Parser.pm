package Parser;
use Modern::Perl;

sub new {
  my $tokens = shift;
  push $tokens, {type => 'eof'};
  bless {tokens => $tokens};
}

sub expect {
  my ($self, $type) = @_;
  my $token = shift $self->{tokens};
  if ($token->{type} ne $type) {
    die "expected $type, found $token->{type}";
  }
  $token;
}

# this method just serves as a shorthand to look better
sub match {
  my ($self, $match) = @_;
  $match->($self);
}
 

sub try {
  my ($self, $match) = @_;
  my @tokens = @{ $self->{tokens} };

  my $value = eval { $self->match($match); };
  if (!$@) {
    return $value;
  }
  $self->{tokens} = \@tokens;
  ()
}

sub one_of {
  my $self = shift;
  while ($_ = shift) {
    if (my $value = $self->try($_)) {
      return $value;
    }
  }
  die "unable to parse one_of";
}

sub any_of {
  my ($self, $match) = @_;
  my @parts;

  while ($_ = $self->try($match)) {
    push @parts, $_;
  }
  \@parts;
}

sub many_of {
  my ($self, $match) = @_;

  # force the first one not to be `try`d
  [$self->match($match), @{ $self->any_of($match) }];
}

1;
