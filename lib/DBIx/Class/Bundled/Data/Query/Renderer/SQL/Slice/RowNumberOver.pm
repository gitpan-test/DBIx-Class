package Data::Query::Renderer::SQL::Slice::RowNumberOver;

use Data::Query::Constants;
use Data::Query::ExprHelpers;
use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::SubqueryRemap';

sub slice_subquery {
  (limit => 1, offset => 1);
}

sub slice_stability { }

sub _render_slice {
  my ($self, $dq) = @_;
  die "Slice's inner is not a Select"
    unless (my $orig_select = $dq->{from})->{type} eq DQ_SELECT;

  my %remapped = $self->_subquery_remap($orig_select);

  my @inside_select_list = @{$remapped{inside_select_list}};
  my @outside_select_list = @{$remapped{outside_select_list}};
  my @inside_order = @{$remapped{inside_order}};
  my @outside_order = @{$remapped{outside_order}};
  my $default_inside_alias = $remapped{default_inside_alias};
  my $inner_body = $remapped{inner_body};

  my $rno_name = 'rno__row__index';

  my $order = compose { Order($b->{by}, $b->{reverse}, $b->{nulls}, $a) }
                @outside_order, undef;

  my $rno_node = Alias($rno_name, $self->_rno_literal($order));

  my $limit_plus_offset = +{
    %{$dq->{limit}}, value => ($dq->{limit}{value}||0) + ($dq->{offset}{value}||0)
  };

  my $offset_plus = +{
    %{$dq->{limit}}, value => ($dq->{offset}{value}||0)+1
  };

  return $self->_render(
    Select(
      \@outside_select_list,
      Where(
        Operator(
          { 'SQL.Naive' => 'AND' },
          [
            Operator(
              { 'SQL.Naive' => '>=' },
              [ Identifier($rno_name), $offset_plus ],
            ),
            Operator(
              { 'SQL.Naive' => '<=' },
              [ Identifier($rno_name), $limit_plus_offset ],
            ),
          ]
        ),
        Alias(
          $default_inside_alias,
          Select(
            [ @outside_select_list, $rno_node ],
            Alias(
              $default_inside_alias,
              Select(
                \@inside_select_list,
                $inner_body
              ),
            ),
          ),
        )
      )
    )
  );
}

sub _rno_literal {
  my ($self, $order) = @_;
  my ($order_str, @order_bind) = (
    $order
      ? @{$self->render($order)}
      : ('')
  );
  return +{
    type => DQ_LITERAL,
    subtype => 'SQL',
    literal => "ROW_NUMBER() OVER( $order_str )",
    values => \@order_bind
  };
}

1;
