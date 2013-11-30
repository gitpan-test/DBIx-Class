package Data::Query::Renderer::SQL::Slice::SubqueryRemap;

use Data::Query::ExprHelpers;
use Moo::Role;

sub _subquery_remap_select {
  my ($self, $orig_select) = @_;

  my $gensym_count;
  my $default_inside_alias;

  my @inside_select_list = map {
    if (is_Alias) {
      $_;
    } elsif (is_Identifier) {
      my @el = @{$_->{elements}};
      if (@el == 2 and $el[0] eq ($default_inside_alias ||= $el[0])) {
        $_;
      } else {
        Alias(join('__', @el), $_);
      }
    } else {
      Alias(sprintf("GENSYM__%03i",++$gensym_count), $_);
    }
  } @{$orig_select->{select}};

  my @outside_select_list = map {
    if (is_Alias) {
      Identifier($_->{to});
    } else {
      $_;
    }
  } @inside_select_list;

  return (
    inside_select_list => \@inside_select_list,
    outside_select_list => \@outside_select_list,
    default_inside_alias => $default_inside_alias||'me',
  );
}

sub _subquery_remap {
  my ($self, $orig_select) = @_;

  my $gensym_count;
  my %select_remap = $self->_subquery_remap_select($orig_select);

  my $default_inside_alias = $select_remap{default_inside_alias};
  my @inside_select_list = @{$select_remap{inside_select_list}};
  my @outside_select_list = @{$select_remap{outside_select_list}};

  my %alias_map = map {
    if (is_Alias and is_Identifier $_->{from}) {
      +(
        join('.',@{$_->{from}{elements}}) => Identifier($_->{to}),
        $_->{from}{elements}[-1] => Identifier($_->{to}),
      )
    } elsif (is_Identifier) {
      +(
        join('.',@{$_->{elements}}) => $_,
        $_->{elements}[-1] => $_,
      )
    } else {
      +()
    }
  } @inside_select_list;

  my @inside_order;
  my $inner_body = do {
    my $order = $orig_select->{from};
    while (is_Order $order) {
      push @inside_order, $order;
      $order = $order->{from};
    }
    $order;
  };

  my $order_gensym_count;
  my @outside_order = map {
    my $by = $_->{by};
    if (is_Identifier $by) {
      $default_inside_alias ||= $by->{elements}[0]
        if @{$by->{elements}} == 2;
      my $mapped_by
        = $alias_map{join('.', @{$by->{elements}})}
          ||= do {
                if (
                  @{$by->{elements}} == 2
                  and $by->{elements}[0] eq $default_inside_alias
                ) {
                  push @inside_select_list, $by;
                  $by;
                } else {
                  my $name = sprintf("ORDER__BY__%03i",++$order_gensym_count);
                  push @inside_select_list, Alias($name, $by);
                  Identifier($name);
                }
              };
      Order($mapped_by, $_->{reverse}, $_->{nulls});
    } else {
      my $name = sprintf("ORDER__BY__%03i",++$order_gensym_count);
      push @inside_select_list, Alias($name, $by);
      Order(Identifier($name), $_->{reverse}, $_->{nulls});
    }
  } @inside_order;

  $default_inside_alias ||= 'me';

  return (
    inside_select_list => \@inside_select_list,
    outside_select_list => \@outside_select_list,
    inside_order => \@inside_order,
    outside_order => \@outside_order,
    default_inside_alias => $default_inside_alias,
    inner_body => $inner_body,
  );
}

1;
