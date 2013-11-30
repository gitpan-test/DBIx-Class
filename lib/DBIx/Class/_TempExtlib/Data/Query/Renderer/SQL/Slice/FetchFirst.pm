package Data::Query::Renderer::SQL::Slice::FetchFirst;

use Data::Query::ExprHelpers;
use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::SubqueryRemap';

sub _render_slice_limit {
  my ($self, $dq) = @_;
  return [
    ($dq->{from} ? $self->_render($dq->{from}) : ()),
    $self->_format_keyword('FETCH FIRST'),
    sprintf("%i", $dq->{limit}{value}),
    $self->_format_keyword('ROWS ONLY')
  ];
}

sub slice_subquery {
  (offset => 1);
}

sub slice_stability {
  (offset => 'requires');
}

sub _slice_type { 'FetchFirst' }

sub _render_slice {
  my ($self, $dq) = @_;
  unless ($dq->{offset}) {
    return $self->_render_slice_limit($dq);
  }
  unless ($dq->{order_is_stable}) {
    die $self->_slice_type." limit style requires a stable order";
  }
  die "Slice's inner is not a Select"
    unless is_Select my $orig_select = $dq->{from};

  my %remapped = $self->_subquery_remap($orig_select);

  my @inside_select_list = @{$remapped{inside_select_list}};
  my @outside_select_list = @{$remapped{outside_select_list}};
  my @inside_order = @{$remapped{inside_order}};
  my @outside_order = @{$remapped{outside_order}};
  my $default_inside_alias = $remapped{default_inside_alias};
  my $inner_body = $remapped{inner_body};

  my $limit_plus_offset = +{
    %{$dq->{limit}}, value => $dq->{limit}{value} + $dq->{offset}{value}
  };

  return $self->_render(
    map {
      ($dq->{preserve_order} and @outside_order)
        ? Select(
          \@outside_select_list,
          compose {
            Order($b->{by}, $b->{reverse}, $b->{nulls}, $a)
          } (
            @outside_order,
            Alias($default_inside_alias, $_)
          )
        )
        : $_
    } (
      Slice(
        undef, $dq->{limit},
        Select(
          [
            @outside_select_list,
            $dq->{preserve_order}
              ? (grep @{$_->{elements}} == 1,
                  map $_->{by}, @outside_order)
              : (),
          ],
          compose {
            Order($b->{by}, !$b->{reverse}, -($b->{nulls}||0), $a)
          } (
            @outside_order,
            Alias(
              $default_inside_alias,
              Slice(
                undef, $limit_plus_offset,
                Select(
                  \@inside_select_list,
                  compose {
                    Order($b->{by}, $b->{reverse}, $b->{nulls}, $a)
                  } @inside_order, $inner_body
                )
              )
            )
          )
        )
      )
    )
  );
}

1;
