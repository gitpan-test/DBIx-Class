package Data::Query::Renderer::SQL::Naive;

use strictures 1;

use SQL::ReservedWords;
use Data::Query::ExprHelpers;

use Moo;
use namespace::clean;

has reserved_ident_parts => (
  is => 'ro', default => sub {
    our $_DEFAULT_RESERVED ||= { map +($_ => 1), SQL::ReservedWords->words }
  }
);

has quote_chars => (is => 'ro', default => sub { [''] });

has identifier_sep => (is => 'ro', default => sub { '.' });

has simple_ops => (is => 'ro', builder => '_default_simple_ops');

has lc_keywords => (is => 'ro', default => sub { 0 });

has always_quote => (is => 'ro', default => sub { 0 });

has collapse_aliases => (is => 'ro', default => sub { 1 });

sub _default_simple_ops {
  +{
    (map +($_ => 'binop'), qw(= > < >= <= != LIKE), 'NOT LIKE' ),
    (map +($_ => 'unop'), qw(NOT) ),
    (map +($_ => 'unop_reverse'), ('IS NULL', 'IS NOT NULL')),
    (map +($_ => 'flatten'), qw(AND OR) ),
    (map +($_ => 'in'), ('IN', 'NOT IN')),
    (map +($_ => 'between'), ('BETWEEN', 'NOT BETWEEN')),
    (apply => 'apply'),
  }
}

sub render {
  my $self = shift;
  $self->_flatten_structure($self->_render(@_))
}

sub _flatten_structure {
  my ($self, $struct) = @_;
  my @bind;
  [ do {
      my @p = map {
        my $r = ref;
        if (!$r) { $_ }
        elsif ($r eq 'ARRAY') {
          my ($sql, @b) = @{$self->_flatten_structure($_)};
          push @bind, @b;
          $sql;
        }
        elsif ($r eq 'HASH') { push @bind, $_; () }
        else { die "_flatten_structure can't handle ref type $r for $_" }
      } @$struct;
      join '', map {
        ($p[$_], (($p[$_+1]||',') eq ',') ? () : (' '))
      } 0 .. $#p;
    },
    @bind
  ];
}

# I presented this to permit strange people to easily supply a patch to lc()
# their keywords, as I have heard many desire to do, lest they infect me
# with whatever malady caused this desire by their continued proximity for
# want of such a feature.
#
# Then I realised that SQL::Abstract compatibility work required it.
#
# FEH.

sub _format_keyword { $_[0]->lc_keywords ? lc($_[1]) : $_[1] }

sub _render {
  unless (ref($_[1]) eq 'HASH') {
    die "Expected hashref, got ".(defined($_[1])?$_[1]:'undef');
  }
  $_[0]->${\"_render_${\(lc($_[1]->{type})||'broken')}"}($_[1]);
}

sub _render_broken {
  my ($self, $dq) = @_;
  require Data::Dumper::Concise;
  die "Broken DQ entry: ".Data::Dumper::Concise::Dumper($dq);
}

sub _render_identifier {
  die "Unidentified identifier (SQL can no has \$_)"
    unless my @i = @{$_[1]->{elements}};
  # handle single or paired quote chars
  my ($q1, $q2) = @{$_[0]->quote_chars}[0,-1];
  my $always_quote = $_[0]->always_quote;
  my $res_check = $_[0]->reserved_ident_parts;
  return [
    join
      $_[0]->identifier_sep,
      map +(
        $_ eq '*' # Yes, this means you can't have a column just called '*'.
          ? $_    # Yes, this is a feature. Go shoot the DBA if he disagrees.
          : ( # reserved are stored uc, quote if non-word
              ($always_quote and $q1) || $res_check->{+uc} || /\W/
                ? $q1.$_.$q2
                : $_
            )
      ), @i
  ];
}

sub _render_value {
  [ '?', $_[1] ]
}

sub _operator_type { 'SQL.Naive' }

sub _render_operator {
  my ($self, $dq) = @_;
  my $op = $dq->{operator};
  unless (exists $op->{$self->_operator_type}) {
    $op->{$self->_operator_type} = $self->_convert_op($dq);
  }
  my $op_name = $op->{$self->_operator_type};
  if (my $op_type = $self->simple_ops->{$op_name}) {
    return $self->${\"_handle_op_type_${op_type}"}($op_name, $dq);
  } elsif (my $meth = $self->can("_handle_op_special_${op_name}")) {
    return $self->$meth($dq);
  }
  if (my $argc = @{$dq->{args}}) {
    if ($argc == 1) {
      return $self->_handle_op_type_unop($op_name, $dq);
    } elsif ($argc == 2) {
      return $self->_handle_op_type_binop($op_name, $dq);
    }
  }
  die "Unsure how to handle ${op_name}";
}

sub _maybe_parenthesise {
  my ($self, $dq) = @_;
  for ($dq) {
    return is_Select() || is_Group() || is_Slice() || is_Having()
      ? [ '(', $self->_render($dq), ')' ]
      : $self->_render($dq);
  }
}

sub _handle_op_type_binop {
  my ($self, $op_name, $dq) = @_;
  die "${op_name} registered as binary op but args contain "
      .scalar(@{$dq->{args}})." entries"
    unless @{$dq->{args}} == 2;
  [
    $self->_maybe_parenthesise($dq->{args}[0]),
    $op_name,
    $self->_maybe_parenthesise($dq->{args}[1]),
  ]
}

sub _handle_op_type_unop {
  my ($self, $op_name, $dq) = @_;
  die "${op_name} registered as unary op but args contain "
      .scalar(@{$dq->{args}})." entries"
    unless @{$dq->{args}} == 1;
  [
    '(',
    $op_name,
    $self->_render($dq->{args}[0]),
    ')',
  ]
}

sub _handle_op_type_unop_reverse {
  my ($self, $op_name, $dq) = @_;
  die "${op_name} registered as unary op but args contain "
      .scalar(@{$dq->{args}})." entries"
    unless @{$dq->{args}} == 1;
  [
    $self->_render($dq->{args}[0]),
    $op_name,
  ]
}

sub _handle_op_type_flatten {
  my ($self, $op_name, $dq) = @_;
  my @argq = @{$dq->{args}};
  my @arg_final;
  while (my $arg = shift @argq) {

    unless (is_Operator($arg)) {
      push @arg_final, $arg;
      next;
    }

    my $op = $arg->{operator};
    unless (exists $op->{$self->_operator_type}) {
      $op->{$self->_operator_type} = $self->_convert_op($arg);
    }
  
    if ($op->{$self->_operator_type} eq $op_name) {
      unshift @argq, @{$arg->{args}};
    } else {
      push @arg_final, $arg;
    }
  }
  [ '(',
      intersperse(
        $self->_format_keyword($op_name),
        map $self->_maybe_parenthesise($_), @arg_final
      ),
    ')'
  ];
}

sub _handle_op_type_in {
  my ($self, $op, $dq) = @_;
  my ($lhs, @in) = @{$dq->{args}};
  [ $self->_render($lhs),
    $op,
    '(',
      intersperse(',', map $self->_render($_), @in),
    ')'
  ];
}

sub _handle_op_type_between {
  my ($self, $op_name, $dq) = @_;
  my @args = @{$dq->{args}};
  if (@args == 3) {
    my ($lhs, $rhs1, $rhs2) = (map $self->_maybe_parenthesise($_), @args);
    [ '(', $lhs, $op_name, $rhs1, 'AND', $rhs2, ')' ];
  } elsif (@args == 2 and is_Literal $args[1]) {
    my ($lhs, $rhs) = (map $self->_render($_), @args);
    [ '(', $lhs, $op_name, $rhs, ')' ];
  } else {
    die "Invalid args for between: ${\scalar @args} given";
  }
}

sub _handle_op_type_apply {
  my ($self, $op_name, $dq) = @_;
  my ($func, @args) = @{$dq->{args}};
  die "Function name must be identifier"
    unless is_Identifier $func;
  my $ident = do {
    # The problem we have here is that built-ins can't be quoted, generally.
    # I rather wonder if things like MAX(...) need to -not- be handled as
    # an apply and instead of something else, maybe a parenop type - but
    # as an explicitly Naive renderer this seems like a reasonable answer.
    local @{$self}{qw(reserved_ident_parts always_quote)};
    $self->_render_identifier($func)->[0];
  };
  [
    "$ident(",
      intersperse(',', map $self->_maybe_parenthesise($_), @args),
    ')'
  ]
}

sub _convert_op {
  my ($self, $dq) = @_;
  if (my $perl_op = $dq->{'operator'}->{'Perl'}) {
    for ($perl_op) {
      $_ eq '==' and return '=';
      $_ eq 'eq' and return '=';
      $_ eq '!' and return 'NOT';
    }
    return uc $perl_op; # hope!
  }
  die "Can't convert non-perl op yet";
}

sub _render_select {
  my ($self, $dq) = @_;
  die "Empty select list" unless @{$dq->{select}};

  # it is, in fact, completely valid for there to be nothing for us
  # to project from since many databases handle 'SELECT 1;' fine

  my @select = intersperse(',',
    map +(is_Alias()
           ? $self->_render_alias($_, $self->_format_keyword('AS'))
           : $self->_render($_)), @{$dq->{select}}
  );

  return [
    $self->_format_keyword('SELECT'),
    \@select,
    # if present this may be a bare FROM, a FROM+WHERE, or a FROM+WHERE+GROUP
    # since we're the SELECT and therefore always come first, we don't care.
    ($dq->{from}
       ? ($self->_format_keyword('FROM'), @{$self->_render($dq->{from})})
       : ()
    ),
  ];
}

sub _render_alias {
  my ($self, $dq, $as) = @_;
  # FROM foo foo -> FROM foo
  # FROM foo.bar bar -> FROM foo.bar
  if ($self->collapse_aliases) {
    if (is_Identifier(my $from = $dq->{from})) {
      if ($from->{elements}[-1] eq $dq->{to}) {
        return $self->_render($from);
      }
    }
  }
  return [
    $self->_maybe_parenthesise($dq->{from}),
    $as || '',
    $self->_render_identifier({ elements => [ $dq->{to} ] })
  ];
}

sub _render_literal {
  my ($self, $dq) = @_;
  unless ($dq->{subtype} eq 'SQL') {
    die "Can't render non-SQL literal";
  }
  if (defined($dq->{literal})) {
    return [
      $dq->{literal}, @{$dq->{values}||[]}
    ];
  } elsif ($dq->{parts}) {
    return [ map $self->_render($_), @{$dq->{parts}} ];
  } else {
    die "Invalid SQL literal - neither 'literal' nor 'parts' found";
  }
}

sub _render_join {
  my ($self, $dq) = @_;
  my ($left, $right) = @{$dq}{qw(left right)};
  my $rhs = $self->_render($right);
  [
    $self->_render($left), $self->_format_join_keyword($dq),
    (is_Join($right) ? ('(', $rhs, ')') : $rhs),
    ($dq->{on}
      ? ($self->_format_keyword('ON'), $self->_render($dq->{on}))
      : ())
  ];
}

sub _format_join_keyword {
  my ($self, $dq) = @_;
  if ($dq->{outer}) {
    $self->_format_keyword(uc($dq->{outer}).' JOIN');
  } elsif ($dq->{on}) {
    $self->_format_keyword('JOIN');
  } else {
    ','
  }
}

sub _render_where {
  my ($self, $dq) = @_;
  my ($from, $where) = @{$dq}{qw(from where)};
  while (is_Where $from) {
    $where = Operator({ 'SQL.Naive' => 'AND' }, [ $from->{where}, $where ]);
    $from = $from->{from};
  }
  my $keyword = (is_Group($from) ? 'HAVING' : 'WHERE');
  [
    ($from ? $self->_render($from) : ()),
    $self->_format_keyword($keyword),
    $self->_render($where)
  ]
}

sub _order_chunk {
  my ($self, $dq) = @_;
  return +(
    $self->_render($dq->{by}),
    ($dq->{reverse}
      ? $self->_format_keyword('DESC')
      : ()),
    ($dq->{nulls} && $dq->{nulls} =~ /^(first|last)$/i
      ? $self->_format_keyword('NULLS '.$dq->{nulls})
      : ()),
  );
}

sub _render_order {
  my ($self, $dq) = @_;
  my @ret = (
    $self->_format_keyword('ORDER BY'),
    $self->_order_chunk($dq),
  );
  my $from;
  while ($from = $dq->{from}) {
    last unless is_Order $from;
    $dq = $from;
    push @ret, (
      ',',
      $self->_order_chunk($dq),
    );
  }
  unshift @ret, $self->_render($from) if $from;
  \@ret;
}

sub _render_group {
  my ($self, $dq) = @_;
  # this could also squash like order does. but I dunno whether that should
  # move somewhere else just yet.
  my @ret = (
    ($dq->{from} ? $self->_render($dq->{from}) : ()),
    (@{$dq->{by}}
      ? (
          $self->_format_keyword('GROUP BY'),
          intersperse(',', map $self->_render($_), @{$dq->{by}})
         )
      : ())
  );
  \@ret;
}

sub _render_delete {
  my ($self, $dq) = @_;
  my ($target, $where) = @{$dq}{qw(target where)};
  [ $self->_format_keyword('DELETE FROM'), 
    $self->_render($target),
    ($where
      ? ($self->_format_keyword('WHERE'), $self->_render($where))
      : ())
  ];
}

sub _render_update {
  my ($self, $dq) = @_;
  my ($target, $set, $where) = @{$dq}{qw(target set where)};
  unless ($set) {
    die "Must have set key - names+value keys not yet tested";
    my ($names, $value) = @{$dq}{qw(names value)};
    die "Must have names and value or set" unless $names and $value;
    die "names and value must be same size" unless @$names == @$value;
    $set = [ map [ $names->[$_], $value->[$_] ], 0..$#$names ];
  }
  my @rendered_set = intersperse(
    ',', map [ intersperse('=', map $self->_render($_), @$_) ], @{$set}
  );
  [ $self->_format_keyword('UPDATE'),
    $self->_render($target),
    $self->_format_keyword('SET'),
    @rendered_set,
    ($where
      ? ($self->_format_keyword('WHERE'), $self->_render($where))
      : ())
  ];
}

sub _render_insert {
  my ($self, $dq) = @_;
  my ($target, $names, $values, $returning)
    = @{$dq}{qw(target names values returning)};
  unless ($values) {
    die "Must have values key - sets key not yet implemented";
  }
  [ $self->_format_keyword('INSERT INTO'),
    $self->_render($target),
    ($names
      ? ('(', intersperse(',', map $self->_render($_), @$names), ')')
      : ()),
    (@$values && @{$values->[0]}
      ? ($self->_format_keyword('VALUES'),
         intersperse(',',
           map [ '(', intersperse(',', map $self->_render($_), @$_), ')' ],
             @$values
         ))
      : ($self->_insert_default_values)),
    ($returning
      ? ($self->_format_keyword('RETURNING'),
         intersperse(',', map $self->_render($_), @$returning))
      : ()),
  ];
}

sub _insert_default_values {
  my ($self) = @_;
  $self->_format_keyword('DEFAULT VALUES'),
}

1;
