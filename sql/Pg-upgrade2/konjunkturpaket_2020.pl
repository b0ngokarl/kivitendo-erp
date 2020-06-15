# @tag: konjunkturpaket_2020
# @description: Deutsches Konjunkturpaket 2020
# @depends: release_3_5_5
package SL::DBUpgrade2::konjunkturpaket_2020;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DB::Chart;

use List::MoreUtils qw(any);
use Data::Dumper;

sub update {
  my ($self) = @_;

  # checks:
  # 1. detect if client uses 4, 5 or 6 digits for ledger accnos
  #    bonus: call fails with a good error message if client has mixed accnos
  # 2. create tax accnos based on the result of 1
  # 3. check if created accnos are not in use, otherwise fail with a error message

  # do:
  # 1. -> create tax accnos in chart

  $self->{length_of_accounts} = SL::DATEV->new->check_valid_length_of_accounts(return_length => 1);

  die $::locale->text("invalid length of accounts") unless $self->{length_of_accounts} =~ /[4-6]/;

  # test foreach
  # $self->{length_of_accounts} = 6;

  foreach my $key (keys %{ $self->{accnos} }) {
    $self->{accnos}{$key} *=10  if $self->{length_of_accounts} == 5;
    $self->{accnos}{$key} *=100 if $self->{length_of_accounts} == 6;
    # check if chart accno already exists
    if (ref SL::DB::Chart->new(accno => $self->{accnos}{$key})->load(speculative => 1) eq 'SL::DB::Chart') {
      die $::locale->text("Chart #1 already exists, cannot safely upgrade the tax charts. Please contact your kivi admin",  $self->{accnos}{$key});
    }
  }

  $self->db_query(<<EOSQL);
INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_eur, datevautomatik)
VALUES ($self->{accnos}{base_five_accno_credit}, 'Mwst reduziert reduziert', 'A', 'E','AP_tax:IC_taxpart:IC_taxservice',2,27,'f')
EOSQL

}

sub run {
  my ($self) = @_;

  # 1. upgrade is only important for german companies
  # set only basic numbers in 4 digits for the two german DATEV standard ledgers
  # and upgrade

  if ($self->check_coa('Germany-DATEV-SKR03EU')) {
    $self->{accnos} = { base_five_accno_credit => 1779,
                        base_sixt_accno_credit => 1781,
                        base_five_accno_debit  => 1579,
                        base_sixt_accno_debit  => 1811,
                      };
    $self->update;
    return 1;
  }

  if ($self->check_coa('Germany-DATEV-SKR04EU')) {
    $self->{accnos} = { base_five_accno_credit => 1459,
                        base_sixt_accno_credit => 1472,
                        base_five_accno_debit  => 3809,
                        base_sixt_accno_debit  => 3811,
                      };
    $self->update;
    return 1;
  }

  if (any { $self->check_coa($_) } qw(Switzerland-deutsch-MWST-2014 Switzerland-deutsch-ohneMWST-2014 Switzerland-deutsch-Verein-2017)) {
    # Nichts zu tun für diese Kontenrahmen
    return 1;
  }

  die $::locale->text('This database upgrade is incompatible with the installed chart of accounts.');
}

1;
