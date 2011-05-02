use strict;
use warnings;

use Test::More;
use Test::Exception;
use Try::Tiny;
use lib qw(t/lib);
use DBICTest;

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_DB2_${_}" } qw/DSN USER PASS/};

#warn "$dsn $user $pass";

plan skip_all => 'Set $ENV{DBICTEST_DB2_DSN}, _USER and _PASS to run this test'
  unless ($dsn && $user);

my $schema = DBICTest::Schema->connect($dsn, $user, $pass);

my $dbh = $schema->storage->dbh;

# test RNO and name_sep detection
my $name_sep = $dbh->get_info(41);

is $schema->storage->sql_maker->name_sep, $name_sep,
  'name_sep detection';

my $have_rno = try {
  $dbh->selectrow_array(
"SELECT row_number() OVER (ORDER BY 1) FROM sysibm${name_sep}sysdummy1"
  );
  1;
};

is $schema->storage->sql_maker->limit_dialect,
  ($have_rno ? 'RowNumberOver' : 'FetchFirst'),
  'limit_dialect detection';

eval { $dbh->do("DROP TABLE artist") };

$dbh->do("CREATE TABLE artist (artistid INTEGER GENERATED BY DEFAULT AS IDENTITY (START WITH 1, INCREMENT BY 1), name VARCHAR(255), charfield CHAR(10), rank INTEGER DEFAULT 13);");

my $ars = $schema->resultset('Artist');
is ( $ars->count, 0, 'No rows at first' );

# test primary key handling
my $new = $ars->create({ name => 'foo' });
ok($new->artistid, "Auto-PK worked");

# test explicit key spec
$new = $ars->create ({ name => 'bar', artistid => 66 });
is($new->artistid, 66, 'Explicit PK worked');
$new->discard_changes;
is($new->artistid, 66, 'Explicit PK assigned');

# test populate
lives_ok (sub {
  my @pop;
  for (1..2) {
    push @pop, { name => "Artist_$_" };
  }
  $ars->populate (\@pop);
});

# test populate with explicit key
lives_ok (sub {
  my @pop;
  for (1..2) {
    push @pop, { name => "Artist_expkey_$_", artistid => 100 + $_ };
  }
  $ars->populate (\@pop);
});

# count what we did so far
is ($ars->count, 6, 'Simple count works');

# test LIMIT support
my $lim = $ars->search( {},
  {
    rows => 3,
    offset => 4,
    order_by => 'artistid'
  }
);
is( $lim->count, 2, 'ROWS+OFFSET count ok' );
is( $lim->all, 2, 'Number of ->all objects matches count' );

# Limit with select-lock
TODO: {
  local $TODO = "Seems we can't SELECT ... FOR ... on subqueries";
  lives_ok {
    $schema->txn_do (sub {
      isa_ok (
        $schema->resultset('Artist')->find({artistid => 1}, {for => 'update', rows => 1}),
        'DBICTest::Schema::Artist',
      );
    });
  } 'Limited FOR UPDATE select works';
}

# test iterator
$lim->reset;
is( $lim->next->artistid, 101, "iterator->next ok" );
is( $lim->next->artistid, 102, "iterator->next ok" );
is( $lim->next, undef, "next past end of resultset ok" );

# test FetchFirst limit dialect syntax
{
  local $schema->storage->sql_maker->{limit_dialect} = 'FetchFirst';

  my $lim = $ars->search({}, {
    rows => 3,
    offset => 2,
    order_by => 'artistid',
  });

  is $lim->count, 3, 'fetch first limit count ok';

  is $lim->all, 3, 'fetch first number of ->all objects matches count';

  is $lim->next->artistid, 3, 'iterator->next ok';
  is $lim->next->artistid, 66, 'iterator->next ok';
  is $lim->next->artistid, 101, 'iterator->next ok';
  is $lim->next, undef, 'iterator->next past end of resultset ok';
}

my $test_type_info = {
    'artistid' => {
        'data_type' => 'INTEGER',
        'is_nullable' => 0,
        'size' => 10
    },
    'name' => {
        'data_type' => 'VARCHAR',
        'is_nullable' => 1,
        'size' => 255
    },
    'charfield' => {
        'data_type' => 'CHAR',
        'is_nullable' => 1,
        'size' => 10
    },
    'rank' => {
        'data_type' => 'INTEGER',
        'is_nullable' => 1,
        'size' => 10
    },
};


my $type_info = $schema->storage->columns_info_for('artist');
is_deeply($type_info, $test_type_info, 'columns_info_for - column data types');

done_testing;

# clean up our mess
END {
    my $dbh = eval { $schema->storage->_dbh };
    $dbh->do("DROP TABLE artist") if $dbh;
}
