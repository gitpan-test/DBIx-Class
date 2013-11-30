package Data::Query::Renderer::Perl;

sub intersperse { my $i = shift; my @i = map +($_, $i), @_; pop @i; @i }

use Data::Query::Constants qw(DQ_IDENTIFIER);
use Moo;

has simple_ops => (
  is => 'ro', builder => '_build_simple_ops'
);

sub _build_simple_ops {
  +{
    (map +($_ => 'binop'), qw(== > < >= <= != eq ne gt lt ge le and or)),
    (map +($_ => 'funop'), qw(not ! defined)),
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
          my ($code, @b) = @{$self->_flatten_structure($_)};
          push @bind, @b;
          $code;
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

sub _render {
  $_[0]->${\"_render_${\(lc($_[1]->{type})||'broken')}"}($_[1]);
}

sub _render_broken {
  my ($self, $dq) = @_;
  require Data::Dumper::Concise;
  die "Broken DQ entry: ".Data::Dumper::Concise::Dumper($dq);
}

sub _render_identifier {
  my ($self, $dq) = @_;
  return [
    join '->', '$_', @{$dq->{elements}}
  ];
}

sub _render_value {
  [ '+shift', $_[1] ]
}

sub _operator_type { 'Perl' }

sub _render_operator {
  my ($self, $dq) = @_;
  my $op = $dq->{operator};
  unless (exists $op->{$self->_operator_type}) {
    $op->{$self->_operator_type} = $self->_convert_op($dq);
  }
  my $op_name = $op->{$self->_operator_type};
  if (my $op_type = $self->{simple_ops}{$op_name}) {
    return $self->${\"_handle_op_type_${op_type}"}($op_name, $dq);
  } else {
    die "Unsure how to handle ${op_name}";
  }
}

sub _convert_op { die "No op conversion to perl yet" }

sub _handle_op_type_binop {
  my ($self, $op_name, $dq) = @_;
  die "${op_name} registered as binary op but args contain "
      .scalar(@{$dq->{args}})." entries"
    unless @{$dq->{args}} == 2;
  [
    '(',
    $self->_render($dq->{args}[0]),
    $op_name,
    $self->_render($dq->{args}[1]),
    ')',
  ]
}

sub _handle_op_type_funop {
  my ($self, $op_name, $dq) = @_;
  $self->_handle_funcall($op_name, $dq->{args});
}

sub _handle_op_type_apply {
  my ($self, $op_name, $dq) = @_;
  my ($func, @args) = @{$dq->{args}};
  die "Function name must be identifier"
    unless $func->{type} eq DQ_IDENTIFIER;
  if (@{$func->{elements}} > 1) {
    die "Not decided how to handle multi-part function identifiers yet";
  }
  $self->_handle_funcall($func->{elements}[0], \@args);
}

sub _handle_funcall {
  my ($self, $fun, $args) = @_;
  [
    "${fun}(",
    intersperse(',', map $self->_render($_), @$args),
    ")",
  ]
}

1;
