package Business::OnlinePayment::Ogone;

use warnings;
use strict;

use Business::OnlinePayment 3;
use Digest::SHA qw(sha1_hex sha256_hex sha512_hex);

use vars qw(@ISA);

@ISA = qw(Business::OnlinePayment);

=head1 NAME

Business::OnlinePayment::Ogone - Ogone backend for Business::OnlinePayment

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use constant SERVER => 'secure.ogone.com';
use constant STANDARD_PAGE => 'orderstandard.asp';
use constant STANDARD_PAGE_TEST => 'teststd.asp';
use constant TEST_LOGIN => 'test';
use constant PROD_LOGIN => 'prod';
use constant CURRENCY => 'EUR';

our %reverse_map = (# General Payment Parameters
					PSPID => 'login', # affiliate name
					ORDERID => 'order_number', # unique order number
					AMOUNT => 'amount', # amount (multiplied by 100)
					CURRENCY => 'currency', # ISO currency code
					# - customer information
					LANGUAGE => 'language', # language (optional, default: en_US)
					CN => 'name', # name
					EMAIL => 'email', # email address
					OWNERADDRESS => 'address', # street address
					OWNERZIP => 'zip', # zip code
					OWNERTOWN => 'city', # city
					OWNERCTY => 'country', # country
					OWNERTELNO => 'phone', # telephone number
					COM => 'description', # order description
					# Return URLS (chapter 9 of advanced guide)
					CATALOGURL => 'catalogurl',
					HOMEURL => 'homeurl',
					ACCEPTURL => 'accepturl',
					DECLINEURL => 'declineurl',
					EXCEPTIONURL => 'exceptionurl',
					CANCELURL => 'cancelurl',
);					

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

=item currency

Currency is C<EUR>.

=back

=head2 currency

Sets the currency for the transaction from an ISO 4217 alpha currency
code.

    $tx->currency('CHF');

=cut

sub set_defaults {
	my ($self, %opts) = @_;

	$self->build_subs(qw/card_type currency order_number payment_method reference_number sha_passphrase_in sha_passphrase_out/);

	$self->server(SERVER);
	$self->currency(CURRENCY);
	
	return $self;
}

=head2 form_action

Returns form action for Ogone's payment page.

    $action = $tx->form_action();
    $form .= qq{<form action="$action" method="post"};

=cut

sub form_action {
	my ($self) = @_;
	my ($login, $page, %fields);
	
	if ($self->test_transaction) {
		$login = TEST_LOGIN;
	}
	else {
		$login = PROD_LOGIN;
	}

	return 'https://' . join('/', $self->server, 'ncol', $login, STANDARD_PAGE);
}

=head2 form_fields

Returns hash with fields and values for the form send to
Ogone's payment page.

    %fields = $tx->form_fields();

    for my $f (keys %fields) {
        push (@hidden, qq{<input type="hidden" name="$f" value="$fields{$f}">});
    }

    $form .= join("\n", @hidden);
	
    $form .= q{<input type="submit" value="Pay"></form>};

=cut

sub form_fields {
	my ($self) = @_;
	my (%fields, $sha_passphrase);

	%fields = $self->_revmap_fields();

	# amount to be paid needs to be multiplied by 100 for the payment request
	$fields{AMOUNT} *= 100;
	
	if ($sha_passphrase = $self->sha_passphrase_in()) {
		$fields{SHASIGN} = $self->sha_signature($self->sha_passphrase_in, %fields);
	}
	
	return %fields;
}

=head2 reference $data

Store and examine data from Ogone.

=cut

sub reference {
	my ($self, $data) = @_;
	my ($status);

	# status
	$status = $data->{STATUS};

	# set result code
	$self->result_code($status);

	if ($status == 5 || $status == 9) {
		# Authorized resp. Payment requested
		$self->is_success(1);
		$self->authorization($data->{ACCEPTANCE});
		$self->order_number($data->{PAYID});
		$self->reference_number($data->{orderID});
		$self->payment_method($data->{PM});
		$self->card_type($data->{BRAND});
	}
	elsif ($status == 0) {
		# Invalid or incomplete
		$self->is_success(0);
        }
	elsif ($status == 2) {
		# Authorization refused
		$self->is_success(0);
	}
	else {
		$self->is_success(0);
	}	

	return;
}

sub submit {
	my ($self) = @_;

	# does nothing right now

	return 1;
}

=head1 Payment results

The following methods are available in addition to the methods provided by L<Business::OnlinePayment>.

=head2 payment_method

Returns the payment method used by the customer (CreditCard, ...).

=head2 card_type

Returns the card type used by the customer (VISA, MasterCard, ...).

=head2 reference_number

Returns the merchant reference number passed with the payment request.

=head1 SHA signatures

For security reasons it's recommended to use SHA signatures for data passed back
and forth to the Ogone payment gateway. The SHA passphrases are set in Ogone's backend
in the "Technical settings" at "Data and origin verification" (in)
and "Transaction feedback" (out). If the SHA-IN passphrase is set in the backend,
a request without a SHA signature will fail with "unknown order/0/s".

=head2 sha_algorithm ($algorithm)

Sets the SHA algorithm used. Possible values are 1, 256, 512. This has to match
the SHA algorithm in Ogone's backend, otherwise the request will fail with
"unknown order/1/s/". 

Returns the algorithm in use.

=head2 sha_passphrase_in ($sha_passphrase_in)

Sets the passphrase for the SHA-in signature (data check before the payment).

    $tx->sha_passphrase_in('ku6Vo5oc=Hie8eiyu');

Returns the passphrase in use.

=head2 sha_passphrase_out ($sha_passphrase_out)

Sets the passphrase for the SHA-out signature (origin check of the return).

    $tx->sha_passphrase_out('thaiFoo5=Choochu9');

Returns the passphrase in use.

=head2 sha_object ($sha_algorithm)

Returns object used for creating SHA signatures.
A new object will be created if $sha_algorithm is passed or no
object exists yet.

=head2 sha_signature ($sha_passphrase, %fields)

This method calculates the SHA signature which is composed of all
the populated fields in the request by joining the key, the equal
sign, the value and the SHA passphrase for each of these fields.

=cut

sub sha_object {
	my ($self, $sha_algorithm) = @_;
	my ($sha_object, $digest_algorithm);

	if (defined $sha_algorithm) {
		$sha_object = Digest::SHA->new($sha_algorithm);
                $digest_algorithm = $sha_object->algorithm;

                if ($digest_algorithm != 1 && $digest_algorithm != 256 && $digest_algorithm != 512) {
                        die "Invalid SHA digest algorithm (use 1, 256 or 512).";
                }

                $self->{sha_object} = $sha_object;
	}
	
	unless (exists $self->{sha_object}) {
                $self->{sha_object} = Digest::SHA->new(1);
        }

	return $self->{sha_object};	
}

sub sha_algorithm {
	my ($self, $sha_algorithm) = @_;
	my ($sha_object, $algorithm);

	return $self->sha_object($sha_algorithm)->algorithm();
}

sub sha_signature {
	my ($self, $sha_passphrase, %fields) = @_;
	my ($sha_object, @tokens);
	
	for my $key (sort {uc($a) cmp uc($b)} keys %fields) {
		if (defined $fields{$key} && $fields{$key} =~ /\S/) {
			push (@tokens, uc($key), '=', $fields{$key}, $sha_passphrase);
		}
	}

	return $self->sha_object->add(@tokens)->hexdigest();
}

sub _revmap_fields {
	my ($self) = @_;
	my (%content, %reverse, $value);

	%content = $self->content();

	# defaults
	$reverse{CURRENCY} = $self->currency();

	# SHA passphrases
	$self->sha_passphrase_in(delete $content{sha_passphrase_in});
	$self->sha_passphrase_out(delete $content{sha_passphrase_out});
	
	for (keys %reverse_map) {
		$value = $content{$reverse_map{$_}};

		if (defined $value && $value =~ /\S/) {
			$reverse{$_} = $value;
		}
	}

	return %reverse;
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
