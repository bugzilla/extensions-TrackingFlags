# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags::Flag;

use base qw(Bugzilla::Object);

use strict;
use warnings;

use Bugzilla::Constants;
use Bugzilla::Util qw(trim);

###############################
####    Initialization     ####
###############################

use constant DB_TABLE => 'tracking_flags';

use constant DB_COLUMNS => qw(
    id
    name
    description
    sortkey
    is_active
);

use constant LIST_ORDER => 'sortkey';

use constant REQUIRED_CREATE_FIELDS => qw(
    name 
    description
);

use constant UPDATE_COLUMNS => qw(
    name 
    description
    sortkey
    is_active
);

use constant VALIDATORS => {
    name        => \&_check_name,
    description => \&_check_description,
    sortkey     => \&_check_sortkey,
    is_active   => \&Bugzilla::Object::check_boolean, 

};

use constant UPDATE_VALIDATORS => {
    name        => \&_check_name,
    description => \&_check_description,
    sortkey     => \&_check_sortkey,
    is_active   => \&Bugzilla::Object::check_boolean, 
};

###############################
####      Methods          ####
###############################

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    $dbh->do('DELETE FROM tracking_flags WHERE id = ?', undef, $self->id);
    $dbh->bz_commit_transaction();
}

###############################
####      Validators       ####
###############################

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowCodeError('param_required', { param => 'name' });
    return $name;
}

sub _check_description {
    my ($invocant, $description) = @_;
    $description = trim($description);
    $description || ThrowCodeError( 'param_required', { param => 'description' } );
    return $description;
}

sub _check_sortkey {
    my ($invocant, $sortkey) = @_;
    my $skey = trim($sortkey);
    detaint_natural($sortkey)
        || ThrowUserError('field_invalid_sortkey', { sortkey => $skey });
    return $sortkey;
}

sub _check_is_active { return $_[1] ? 1 : 0; }

###############################
####       Setters         ####
###############################

sub set_name        { $_[0]->set('name', $_[1]);        }
sub set_description { $_[0]->set('description', $_[1]); }
sub set_sortkey     { $_[0]->set('sortkey', $_[1]);     }
sub set_is_active   { $_[0]->set('is_active', $_[1]);   }

###############################
####      Accessors        ####
###############################

sub id          { return $_[0]->{'id'};          }
sub name        { return $_[0]->{'name'};        }
sub description { return $_[0]->{'description'}; }
sub sortkey     { return $_[0]->{'sortkey'};     }
sub is_active   { return $_[0]->{'is_active'};   }

sub values {
    my ($self) = @_;
    return $self->{'values'} if exists $self->{'values'};
    $self->{'values'} = Bugzilla::Extension::TrackingFlags::Flag::Value->match({ 
        tracking_flag_id => $self->id
    });
    return $self->{'values'};
}

1;
