package Data::Query::Renderer::SQL::Slice::GenericSubquery;

use Data::Query::ExprHelpers;
use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::SubqueryRemap';

sub slice_subquery {
  (limit => 1, offset => 1);
}

sub slice_stability {
  (limit => 'requires', offset => 'requires');
}

sub _render_slice {
  my ($self, $dq) = @_;
  die "Slice's inner is not a Select"
    unless is_Select my $orig_select = $dq->{from};
  my %remapped = $self->_subquery_remap($orig_select);
  my $first_from = $remapped{inner_body};
  # Should we simply strip until we reach a join/alias/etc. here?
  STRIP: while ($first_from) {
    if (is_Group($first_from)) {
      $first_from = $first_from->{from};
      next STRIP;
    } elsif (is_Where($first_from)) {
      $first_from = $first_from->{from};
      next STRIP;
    } elsif (is_Join($first_from)) {
      $first_from = $first_from->{left};
      next STRIP;
    }
    last STRIP;
  }
  die "WHAT" unless $first_from;
  $first_from = $first_from->{from} if is_Alias($first_from);
  my @main_order;
  foreach my $i (0..$#{$remapped{inside_order}}) {
    my $order = $remapped{inside_order}[$i];
    my $outside = $remapped{outside_order}[$i];
    if (is_Identifier($order->{by})
        and (
          (@{$order->{by}{elements}} == 2
          and $order->{by}{elements}[0] eq $remapped{default_inside_alias})
        or (@{$order->{by}{elements}} == 1))
    ) {
      push @main_order, [
        $outside->{by}, $order->{by}{elements}[-1], $order->{reverse},
        $order->{nulls}
      ];
    } else {
      last;
    }
  }
  
  my $count_alias = 'rownum__emulation';
  my ($op_and, $op_or) = map +{ 'SQL.Naive' => $_ }, qw(AND OR);
  my $count_cond = compose {
    my $lhs = $b->[0];
    my $rhs = Identifier($count_alias, $b->[1]);
    ($lhs, $rhs) = ($rhs, $lhs) if $b->[2];
    my $no_nulls = ($b->[3]||'') eq 'none';
    my ($this) = map {
      $no_nulls
        ? $_
        : Operator($op_or, [
            Operator($op_and, [
              Operator({ 'SQL.Naive' => 'IS NOT NULL' }, [ $lhs ]),
              Operator({ 'SQL.Naive' => 'IS NULL' }, [ $rhs ]),
            ]),
            $_
          ])
    } Operator({ 'SQL.Naive' => '>' }, [ $lhs, $rhs ]);
    my $final = (
      $a
        ? Operator($op_or, [
            $this,
            Operator($op_and, [
              (map {
                $no_nulls
                  ? $_
                  : Operator($op_or, [
                      Operator($op_and, [
                        map Operator({ 'SQL.Naive' => 'IS NULL' }, [ $_ ]),
                          $lhs, $rhs
                      ]),
                      $_,
                    ])
              } Operator({ 'SQL.Naive' => '=' }, [ $lhs, $rhs ])),
              $a
            ])
          ])
        : $this
    );
    $final;
  } @main_order, undef;
  my $count_sel = Select(
    [ Operator({ 'SQL.Naive' => 'apply' }, [ Identifier('COUNT'), Identifier('*') ]) ],
    Where(
      $count_cond,
      Alias($count_alias, $first_from)
    )
  );
  my $count_where = Operator(
    { 'SQL.Naive' => ($dq->{offset} ? 'BETWEEN' : '<') },
    [ $count_sel, (
        $dq->{offset}
          ? (
              $dq->{offset},
              {
                %{$dq->{limit}},
                value => $dq->{limit}{value}+$dq->{offset}{value}-1
              }
            )
          : ($dq->{limit})
      )
    ]
  );
  return $self->render(
    Select(
      $remapped{outside_select_list},
      (compose { no warnings 'once'; Order($b->{by}, $b->{reverse}, $b->{nulls}, $a) }
        @{$remapped{outside_order}},
        Where(
          $count_where,
          Alias(
            $remapped{default_inside_alias},
            Select(
              $remapped{inside_select_list},
              $remapped{inner_body},
            )
          )
        )
      )
    )
  );
}

1;
