package SL::Controller::SimpleSystemSetting;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::System::Process;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(type config) ],
  'scalar --get_set_init' => [ qw(defaults object all_objects class manager_class list_attributes list_url supports_reordering) ],
);

__PACKAGE__->run_before('check_type_and_auth');
__PACKAGE__->run_before('setup_javascript', only => [ qw(add create edit update delete) ]);

# Make locales.pl happy: $self->render("simple_system_setting/_default_form")

my %supported_types = (
  bank_account => {
    # Make locales.pl happy: $self->render("simple_system_setting/_bank_account_form")
    class  => 'BankAccount',
    titles => {
      list => t8('Bank accounts'),
      add  => t8('Add bank account'),
      edit => t8('Edit bank account'),
    },
    list_attributes => [
      { method => 'name',                                      title => t8('Name'), },
      { method => 'iban',                                      title => t8('IBAN'), },
      { method => 'bank',                                      title => t8('Bank'), },
      { method => 'bank_code',                                 title => t8('Bank code'), },
      { method => 'bic',                                       title => t8('BIC'), },
      { method => 'reconciliation_starting_date_as_date',      title => t8('Date'),    align => 'right' },
      { method => 'reconciliation_starting_balance_as_number', title => t8('Balance'), align => 'right' },
    ],
  },

  business => {
    # Make locales.pl happy: $self->render("simple_system_setting/_business_form")
    class  => 'Business',
    titles => {
      list => t8('Businesses'),
      add  => t8('Add business'),
      edit => t8('Edit business'),
    },
    list_attributes => [
      { method => 'description',         title => t8('Description'), },
      {                                  title => t8('Discount'), formatter => sub { $_[0]->discount_as_percent . ' %' }, align => 'right' },
      { method => 'customernumberinit',  title => t8('Customernumberinit'), },
    ],
  },

  department => {
    class  => 'Department',
    titles => {
      list => t8('Departments'),
      add  => t8('Add department'),
      edit => t8('Edit department'),
    },
  },

  part_classification => {
    # Make locales.pl happy: $self->render("simple_system_setting/_part_classification_form")
    class  => 'PartClassification',
    titles => {
      list => t8('Part classifications'),
      add  => t8('Add part classification'),
      edit => t8('Edit part classification'),
    },
    list_attributes => [
      { title => t8('Description'),       formatter => sub { t8($_[0]->description) } },
      { title => t8('Type abbreviation'), formatter => sub { t8($_[0]->abbreviation) } },
      { title => t8('Used for Purchase'), formatter => sub { $_[0]->used_for_purchase ? t8('yes') : t8('no') } },
      { title => t8('Used for Sale'),     formatter => sub { $_[0]->used_for_sale     ? t8('yes') : t8('no') } },
      { title => t8('Report separately'), formatter => sub { $_[0]->report_separate   ? t8('yes') : t8('no') } },
    ],
  },

  parts_group => {
    # Make locales.pl happy: $self->render("simple_system_setting/_parts_group_form")
    class  => 'PartsGroup',
    titles => {
      list => t8('Partsgroups'),
      add  => t8('Add partsgroup'),
      edit => t8('Edit partsgroup'),
    },
    list_attributes => [
      { method => 'partsgroup', title => t8('Description') },
      { method => 'obsolete',   title => t8('Obsolete'), formatter => sub { $_[0]->obsolete ? t8('yes') : t8('no') } },
    ],
  },

  price_factor => {
    # Make locales.pl happy: $self->render("simple_system_setting/_price_factor_form")
    class  => 'PriceFactor',
    titles => {
      list => t8('Price Factors'),
      add  => t8('Add Price Factor'),
      edit => t8('Edit Price Factor'),
    },
    list_attributes => [
      { method => 'description',      title => t8('Description') },
      { method => 'factor_as_number', title => t8('Factor'), align => 'right' },
    ],
  },

  pricegroup => {
    # Make locales.pl happy: $self->render("simple_system_setting/_pricegroup_form")
    class  => 'Pricegroup',
    titles => {
      list => t8('Pricegroups'),
      add  => t8('Add pricegroup'),
      edit => t8('Edit pricegroup'),
    },
    list_attributes => [
      { method => 'pricegroup', title => t8('Description') },
      { method => 'obsolete',   title => t8('Obsolete'), formatter => sub { $_[0]->obsolete ? t8('yes') : t8('no') } },
    ],
  },

  project_status => {
    class  => 'ProjectStatus',
    titles => {
      list => t8('Project statuses'),
      add  => t8('Add project status'),
      edit => t8('Edit project status'),
    },
  },

  project_type => {
    class  => 'ProjectType',
    titles => {
      list => t8('Project types'),
      add  => t8('Add project type'),
      edit => t8('Edit project type'),
    },
  },

);

my @default_list_attributes = (
  { method => 'description', title => t8('Description') },
);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('simple_system_setting/list', title => $self->config->{titles}->{list});
}

sub action_new {
  my ($self) = @_;

  $self->object($self->class->new);
  $self->render_form(title => $self->config->{titles}->{add});
}

sub action_edit {
  my ($self) = @_;

  $self->render_form(title => $self->config->{titles}->{edit});
}

sub action_create {
  my ($self) = @_;

  $self->object($self->class->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;

  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ($self->object->can('orphaned') && !$self->object->orphaned) {
    flash_later('error', t8('The object is in use and cannot be deleted.'));

  } elsif ( eval { $self->object->delete; 1; } ) {
    flash_later('info',  t8('The object has been deleted.'));

  } else {
    flash_later('error', t8('The object is in use and cannot be deleted.'));
  }

  $self->redirect_to($self->list_url);
}

sub action_reorder {
  my ($self) = @_;

  $self->class->reorder_list(@{ $::form->{object_id} || [] });
  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_type_and_auth {
  my ($self) = @_;

  $self->type($::form->{type});
  $self->config($supported_types{$self->type}) || die "Unsupported type";

  $::auth->assert($self->config->{auth} || 'config');

  my $pm = (map { s{::}{/}g; "${_}.pm" } $self->class)[0];
  require $pm;

  my $setup = "setup_" . $self->type;
  $self->$setup if $self->can($setup);

  1;
}

sub setup_javascript {
  $::request->layout->use_javascript("${_}.js") for qw(ckeditor/ckeditor ckeditor/adapters/jquery);
}

sub init_class               { "SL::DB::"          . $_[0]->config->{class}                  }
sub init_manager_class       { "SL::DB::Manager::" . $_[0]->config->{class}                  }
sub init_object              { $_[0]->class->new(id => $::form->{id})->load                  }
sub init_all_objects         { $_[0]->manager_class->get_all_sorted                          }
sub init_list_url            { $_[0]->url_for(action => 'list', type => $_[0]->type)         }
sub init_supports_reordering { $_[0]->class->new->can('reorder_list')                        }
sub init_defaults            { SL::DB::Default->get                                          }

sub init_list_attributes {
  my ($self) = @_;

  my $method = "list_attributes_" . $self->type;

  return $self->$method if $self->can($method);
  return $self->config->{list_attributes} // \@default_list_attributes;
}

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->object->id;

  my $params = delete($::form->{object}) || { };

  $self->object->assign_attributes(%{ $params });

  my @errors;

  push @errors, $self->object->validate if $self->object->can('validate');

  if (@errors) {
    flash('error', @errors);
    return $self->render_form(title => $self->config->{titles}->{$is_new ? 'add' : 'edit'});
  }

  $self->object->save;

  flash_later('info', $is_new ? t8('The object has been created.') : t8('The object has been saved.'));

  $self->redirect_to($self->list_url);
}

sub render_form {
  my ($self, %params) = @_;

  my $sub_form_template = SL::System::Process->exe_dir . '/templates/webpages/simple_system_setting/_' . $self->type . '_form.html';

  $self->render(
    'simple_system_setting/form',
    %params,
    sub_form_template => (-f $sub_form_template ? $self->type : 'default'),
  );
}

#
# type-specific helper functions
#

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::SimpleSystemSettings — a common CRUD controller for
various settings in the "System" menu

=head1 AUTHOR

Moritz Bunkus <m.bunkus@linet-services.de>

=cut