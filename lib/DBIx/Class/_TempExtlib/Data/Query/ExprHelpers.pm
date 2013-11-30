package Data::Query::ExprHelpers;

use strictures 1;
use Data::Query::Constants;

use base qw(Exporter);

our @EXPORT = qw(
  perl_scalar_value perl_operator Literal Identifier compose intersperse
  scan_dq_nodes map_dq_tree
);

sub intersperse { my $i = shift; my @i = map +($_, $i), @_; pop @i; @i }

sub perl_scalar_value {
  +{
    type => DQ_VALUE,
    subtype => { Perl => 'Scalar' },
    value => $_[0],
    $_[1] ? (value_meta => $_[1]) : ()
  }
}

sub perl_operator {
  my ($op, @args) = @_;
  +{
    type => DQ_OPERATOR,
    operator => { Perl => $op },
    args => \@args
  }
}

my %map = (
  Join => [ qw(left right on outer) ],
  Alias => [ qw(to from) ],
  Operator => [ qw(operator args) ],
  Select => [ qw(select from) ],
  Where => [ qw(where from) ],
  Order => [ qw(by reverse nulls from) ],
  Group => [ qw(by from) ],
  Delete => [ qw(where target) ],
  Update => [ qw(set where target) ],
  Insert => [ qw(names values target returning) ],
  Slice => [ qw(offset limit from) ],
);

sub Literal {
  my $subtype = shift;
  if (ref($_[0])) {
    return +{
      type => DQ_LITERAL,
      subtype => $subtype,
      parts => $_[0],
    };
  }
  return +{
    type => DQ_LITERAL,
    subtype => $subtype,
    literal => $_[0],
    ($_[1] ? (values => $_[1]) : ())
  };
}

sub Identifier {
  return +{
    type => DQ_IDENTIFIER,
    elements => [ @_ ],
  };
}

foreach my $name (values %Data::Query::Constants::CONST) {
  no strict 'refs';
  my $sub = "is_${name}";
  *$sub = sub {
    my $dq = @_ ? $_[0] : $_;
    $dq->{type} and $dq->{type} eq $name
  };
  push @EXPORT, $sub;
  if (my @map = @{$map{$name}||[]}) {
    *$name = sub {
      my $dq = { type => $name };
      foreach (0..$#map) {
        $dq->{$map[$_]} = $_[$_] if defined $_[$_];
      }

      if (my $optional = $_[$#map+1]) {
        unless(ref $optional eq 'HASH') {
          require Carp;
          Carp::croak("Not a hashreference");
        }
        @{$dq}{keys %$optional} = values %$optional;
      }

      return $dq;
    };
    push @EXPORT, $name;
  }
}

sub is_Having { is_Where($_[0]) and is_Group($_[0]->{from}) }

push @EXPORT, 'is_Having';

sub compose (&@) {
  my $code = shift;
  require Scalar::Util;
  my $type = Scalar::Util::reftype($code);
  unless($type and $type eq 'CODE') {
    require Carp;
    Carp::croak("Not a subroutine reference");
  }
  no strict 'refs';

  return shift unless @_ > 1;

  use vars qw($a $b);

  my $caller = caller;
  local(*{$caller."::a"}) = \my $a;
  local(*{$caller."::b"}) = \my $b;

  $a = pop;
  foreach (reverse @_) {
    $b = $_;
    $a = &{$code}();
  }

  $a;
}

sub scan_dq_nodes {
  my ($cb_map, @queue) = @_;
  while (my $node = shift @queue) {
    if ($node->{type} and my $cb = $cb_map->{$node->{type}}) {
      local $_ = $node;
      $cb->($node);
    }
    push @queue,
      grep ref($_) eq 'HASH',
        map +(ref($_) eq 'ARRAY' ? @$_ : $_),
          @{$node}{grep !/\./, keys %$node};
  }
}

sub map_dq_tree (&;@) {
  my ($block, $in) = @_;
  local $_ = $in;
  $_ = $block->($_) if ref($_) eq 'HASH';
  if (ref($_) eq 'REF' and ref($$_) eq 'HASH') {
    $$_;
  } elsif (ref($_) eq 'HASH') {
    my $mapped = $_;
    local $_;
    +{ map +($_ => &map_dq_tree($block, $mapped->{$_})), keys %$mapped };
  } elsif (ref($_) eq 'ARRAY') {
    [ map &map_dq_tree($block, $_), @$_ ]
  } else {
    $_
  }
}

1;
