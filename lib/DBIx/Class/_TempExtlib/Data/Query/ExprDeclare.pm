package Data::Query::ExprDeclare;

use strictures;
use Data::Query::ExprBuilder::Identifier;
use Data::Query::ExprHelpers;
use Data::Query::Constants;
use Safe::Isa;
use Exporter ();

sub import {
  warnings->unimport('precedence');
  goto &Exporter::import;
}

our @EXPORT = qw(expr);

our @EXPORT_OK = qw(
  SELECT AS FROM BY JOIN ON LEFT WHERE ORDER GROUP DESC LIMIT OFFSET NULLS FIRST LAST
);

sub expr (&) {
  _run_expr($_[0]);
}

sub _run_expr {
  local $_ = Data::Query::ExprBuilder::Identifier->new({
    expr => Identifier(),
  });
  $_[0]->();
}

sub _value {
  if ($_[0]->$_isa('Data::Query::ExprBuilder')) {
    $_[0]->{expr};
  } elsif (ref($_[0])) {
    $_[0]
  } else {
    perl_scalar_value($_[0]);
  }
}

sub AS {
  my $as = shift;
  (bless(\$as, 'LIES::AS'), @_);
}

sub SELECT (&;@) {
  my @select = map _value($_), _run_expr(shift);
  my @final;
  while (@select) {
    my $e = shift @select;
    push @final,
      (ref($select[0]) eq 'LIES::AS'
        ? Alias(${shift(@select)}, $e)
        : $e
     );
  }
      
  my $final = Select(\@final, shift);

  if (is_Slice($_[0])) {
    my ($limit, $offset) = @{+shift}{qw(limit offset)};
    $final = Slice($offset, $limit, $final);
  }

  return $final;
}

sub BY (&;@) { @_ }

sub FROM (&;@) {
  my @from = _run_expr(shift);
  my $from_dq = do {
    if (@from == 2 and ref($from[1]) eq 'LIES::AS') {
      Alias(${$from[1]}, _value($from[0]))
    } elsif (@from == 1) {
      _value($from[0]);
    }
  };
  while (is_Join($_[0])) {
    $from_dq = { %{+shift}, left => $from_dq };
  }
  if (is_Where($_[0])) {
    my $where = shift->{where};
    if (is_Select($from_dq)) {
      $from_dq = Select($from_dq->{select}, Where($where, $from_dq->{from}));
    } else {
      $from_dq = Where($where, $from_dq);
    }
  }
  while (is_Order($_[0])) {
    my $order = shift;
    $from_dq = Order($order->{by}, $order->{reverse}, $order->{nulls}, $from_dq);
  }
  return ($from_dq, @_);
}

sub LEFT {
  my ($join, @rest) = @_;
  die "LEFT used as modifier on non-join ${join}"
    unless is_Join($join);
  return +{ %$join, outer => 'LEFT' }, @rest;
}

sub JOIN (&;@) {
  my ($join) = FROM(\&{+shift});
  my $on = do {
    if ($_[0]->$_isa('LIES::ON')) {
      ${+shift}
    } else {
      undef
    }
  };
  Join(undef, $join, $on), @_;
}

sub ON (&;@) {
  my $on = _value(_run_expr(shift));
  return bless(\$on, 'LIES::ON'), @_;
}

sub WHERE (&;@) {
  my $w = shift;
  return Where(_value(_run_expr($w))), @_;
}

sub DESC { bless({}, 'LIES::DESC'), @_ }
sub NULLS { bless(\shift, 'LIES::NULLS'), @_ }
sub FIRST { 1, @_ }
sub LAST { -1, @_ }

sub ORDER {
  my @order = map _value($_), _run_expr(shift);
  my $reverse = do {
    if ($_[0]->$_isa('LIES::DESC')) {
      shift; 1;
    } else {
      0;
    }
  };
  my $nulls = $_[0]->$_isa('LIES::NULLS') ? ${+shift} : undef;

  return ((compose { Order($b, $reverse, $nulls, $a) } @order, undef), @_);
}

sub LIMIT (&;@) {
  my ($limit) = map _value($_), _run_expr(shift);
  if (is_Slice($_[0])) {
    my $slice = shift;
    return +{ %{$slice}, limit => $limit }, @_;
  }
  return Slice(undef, $limit), @_;
}

sub OFFSET (&;@) {
  my ($offset) = map _value($_), _run_expr(shift);
  return Slice($offset, undef), @_;
}

1;
