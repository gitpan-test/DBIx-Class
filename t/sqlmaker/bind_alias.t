use strict;
use warnings;
use Test::More;

use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;

# Make sure that the conveniences are accurate (and don't error)
alias_check(
  [ _sub => 2 ],
  [ { dbic_colname => '_sub' } => 2 ],
  '[ $name => $val ] === [ { dbic_colname => $name }, $val ]',
);
alias_check(
  [ \'number' => 2 ],
  [ { sqlt_datatype => 'number' } => 2 ],
  '[ \$dt  => $val ] === [ { sqlt_datatype => $dt }, $val ]',
);
alias_check(
  [ undef, 2 ],
  [ {} => 2 ],
  '[ undef,   $val ] === [ {}, $val ]',
);
alias_check(
  [ 2 ],
  [ {} => 2 ],
  '[ $val ]          === [ {}, $val ]',
);
alias_check(
  2,
  [ {} => 2 ],
  '$val              === [ {}, $val ]',
);

done_testing;

sub alias_check {
  my ($bind_alias, $bind_actual, $test) = @_;
  is_same_sql_bind (
    DBICTest->init_schema->resultset('CD')->search({}, {
      group_by => ['me.cdid', \[ 'me.artist - ?', $bind_alias ] ],
    })->as_query,
    '(SELECT me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track FROM cd me GROUP BY me.cdid, me.artist - ?)',
    [ $bind_actual ],
    $test
  );
}
