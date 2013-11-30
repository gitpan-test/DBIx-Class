package Data::Query::ExprBuilder::Identifier;

use strictures 1;

use base qw(Data::Query::ExprBuilder);
use Data::Query::Constants qw(DQ_IDENTIFIER);

sub DESTROY { }

sub can { 
  my $name = $_[1];
  sub {
    return (ref($_[0])||$_[0])->new({
      expr => {
        type => DQ_IDENTIFIER,
        elements => [ @{$_[0]->{expr}{elements}}, $name ]
      },
    });
  };
}

sub AUTOLOAD {
  (my $auto = our $AUTOLOAD) =~ s/.*:://;
  return (ref($_[0])||$_[0])->new({
    expr => {
      type => DQ_IDENTIFIER,
      elements => [ @{$_[0]->{expr}{elements}}, $auto ]
    },
  });
}

1;
