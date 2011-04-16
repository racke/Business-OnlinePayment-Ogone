package Business::OnlinePayment::Ogone;

use warnings;
use strict;

use Business::OnlinePayment 3;
use vars qw(@ISA);

@ISA = qw(Business::OnlinePayment);

=head1 NAME

Business::OnlinePayment::Ogone - Ogone backend for Business::OnlinePayment

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use constant SERVER => 'secure.ogone.com';

=head1 SYNOPSIS

This is a plugin for the L<Business::OnlinePayment> interface.

    use Business::OnlinePayment;

    my $tx = Business::OnlinePayment->new('Ogone');

=head1 METHODS

=head2 set_defaults

Sets the following defaults for Ogone payment:

=over 4

=item server

Server is C<secure.ogone.com>.

=back

=cut

sub set_defaults {
	my ($self, %opts) = @_;

	$self->server(SERVER);
	$self->build_subs();
	
	return $self;
}

=head1 AUTHOR

Stefan Hornburg (Racke), C<< <racke at linuxia.de> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-onlinepayment-ogone at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-OnlinePayment-Ogone>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::OnlinePayment::Ogone


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-OnlinePayment-Ogone>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-OnlinePayment-Ogone>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-OnlinePayment-Ogone>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-OnlinePayment-Ogone/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Stefan Hornburg (Racke).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Business::OnlinePayment::Ogone
