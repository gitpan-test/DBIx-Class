package Data::Query::Renderer::SQL::Slice::RowNum;

use Data::Query::ExprHelpers;
use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::SubqueryRemap';

sub slice_subquery {
  (limit => 1, offset => 1);
}

sub slice_stability {
  (offset => 'check');
}

sub _render_slice {
  my ($self, $dq) = @_;
  die "Slice's inner is not a Select"
    unless is_Select my $orig_select = $dq->{from};
  my %remapped = $self->_subquery_remap_select($orig_select);
  my $inside_select = Alias(
    $remapped{default_inside_alias},
    Select($remapped{inside_select_list}, $orig_select->{from}),
  );
  unless ($dq->{offset}) {
    return $self->render(
      Select(
        $remapped{outside_select_list},
        Where(
          Operator(
            { 'SQL.Naive' => '<=' },
            [
              Literal(SQL => 'ROWNUM'),
              $dq->{limit}
            ]
          ),
          $inside_select
        )
      )
    );
  }
  my ($limit_plus_offset, $offset_plus) = (
    { %{$dq->{limit}}, value => $dq->{limit}{value}+$dq->{offset}{value} },
    { %{$dq->{limit}}, value => $dq->{offset}{value}+1 }
  );

  my $rownum_name = 'rownum__index';

  if ($dq->{order_is_stable}) {
    return $self->render(
      Select(
        $remapped{outside_select_list},
        Where(
          Operator(
            { 'SQL.Naive' => '>=' },
            [ Identifier($rownum_name), $offset_plus ]
          ),
          Alias(
            $remapped{default_inside_alias},
            Select(
              [ @{$remapped{outside_select_list}},
                Alias($rownum_name, Literal(SQL => 'ROWNUM')) ],
              Where(
                Operator(
                  { 'SQL.Naive' => '<=' },
                  [ Literal(SQL => 'ROWNUM'), $limit_plus_offset ]
                ),
                $inside_select,
              )
            )
          )
        )
      )
    );
  } else {
    return $self->render(
      Select(
        $remapped{outside_select_list},
        Where(
          Operator(
            { 'SQL.Naive' => 'BETWEEN' },
            [ Identifier($rownum_name), $offset_plus, $limit_plus_offset ]
          ),
          Alias(
            $remapped{default_inside_alias},
            Select(
              [ @{$remapped{outside_select_list}},
                Alias($rownum_name, Literal(SQL => 'ROWNUM')) ],
              $inside_select
            )
          )
        )
      )
    );
  }
}

1;
