#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Data::Patch' );
}

diag( "Testing Data::Patch $Data::Patch::VERSION, Perl $], $^X" );
