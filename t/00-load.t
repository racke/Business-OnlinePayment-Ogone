#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Business::OnlinePayment::Ogone' ) || print "Bail out!
";
}

diag( "Testing Business::OnlinePayment::Ogone $Business::OnlinePayment::Ogone::VERSION, Perl $], $^X" );
