package Data::Query::ExprBuilder;

use strictures 1;
use Scalar::Util ();
use Data::Query::ExprHelpers qw(perl_scalar_value perl_operator);

use overload (
  # unary operators
  (map {
    my $op = $_;
    $op => sub {
      Data::Query::ExprBuilder->new({
        expr => perl_operator($op => $_[0]->{expr})
      });
    }
  } qw(! neg)),
  # binary operators
  (map {
    my ($overload, $as) = ref($_) ? @$_ : ($_, $_);
    $overload => sub {
      Data::Query::ExprBuilder->new({
        expr => perl_operator(
           $as,
           map {
             (Scalar::Util::blessed($_)
             && $_->isa('Data::Query::ExprBuilder'))
               ? $_->{expr}
               : perl_scalar_value($_)
              # we're called with ($left, $right, 0) or ($right, $left, 1)
            } $_[2] ? @_[1,0] : @_[0,1]
          )
      });
    }
  }
    qw(+ - * / % ** << >> . < > == != lt le gt ge eq ne),

    # since 'and' and 'or' aren't operators we borrow the bitwise ops
    [ '&' => 'and' ], [ '|' => 'or' ],
  ),
  # unsupported
  (map {
    my $op = $_;
    $op => sub { die "Can't use operator $op on a ".ref($_[0]) }
   } qw(<=> cmp x ^ ~)
  ),
  fallback => 1,
); 

sub new {
  bless({ %{$_[1]} }, (ref($_[0])||$_[0]));
}

1;
