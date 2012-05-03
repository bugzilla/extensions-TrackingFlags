# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags::Flag::Value;

use base qw(Bugzilla::Object);

use strict;
use warnings;

use Bugzilla::Constants;
use Bugzilla::Util qw(trim);
use Scalar::Util qw(blessed);

###############################
####    Initialization     ####
###############################

use constant DB_TABLE => 'tracking_flags_values';

use constant DB_COLUMNS => qw(
    id
    tracking_flag_id
    setter_group_id
    value
    sortkey
    is_active
);

use constant LIST_ORDER => 'sortkey';

use constant REQUIRED_CREATE_FIELDS => qw(
    tracking_flag_id
    value
);

use constant UPDATE_COLUMNS => qw(
    tracking_flag_id
    setter_group_id
    value
    sortkey
    is_active
);

use constant VALIDATORS => {
    tracking_flag_id => \&_check_tracking_flag,
    setter_group_id  => \&_check_setter_group,
    value            => \&_check_value,
    sortkey          => \&_check_sortkey,
    is_active        => \&_check_is_active,
};

use constant UPDATE_VALIDATORS => {
    tracking_flag_id => \&_check_tracking_flag,
    setter_group_id  => \&_check_setter_group,
    value            => \&_check_value,
    sortkey          => \&_check_sortkey,
    is_active        => \&_check_is_active,
};

###############################
####       Methods         ####
###############################

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    $dbh->do('DELETE FROM tracking_flags_values WHERE id = ?', undef, $self->id);
    $dbh->bz_commit_transaction();
}

###############################
####      Validators       ####
###############################

sub _check_value {
    my ($invocant, $value) = @_;
    $value = trim($value);
    $value || ThrowCodeError('param_required', { param => 'value' });
    return $value;
}

sub _check_tracking_flag {
    my ($invocant, $flag) = @_;
    if (blessed $flag) {
        return $flag->id;
    }
    $flag = Bugzilla::Extension::TrackingFlags::Flag->new($flag);
    $flag || ThrowCodeError('tracking_flags_invalid_flag_id');
    return $flag->id;
}

sub _check_setter_group {
    my ($invocant, $group) = @_;
    if (blessed $group) { 
        return $group->id;
    }
    $group = Bugzilla::Group->new($group);
    $group || ThrowCodeError('tracking_flags_invalid_setter_group');
    return $group->id;
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

sub set_setter_group { $_[0]->set('setter_group_id', $_[1]); }
sub set_value        { $_[0]->set('value', $_[1]);           }
sub set_sortkey      { $_[0]->set('sortkey', $_[1]);         }
sub set_is_active    { $_[0]->set('is_active', $_[1]);       }


###############################
####      Accessors        ####
###############################

sub id               { return $_[0]->{'id'};               }
sub tracking_flag_id { return $_[0]->{'tracking_flag_id'}; }
sub setter_group_id  { return $_[0]->{'setter_group_id'};  }
sub value            { return $_[0]->{'value'};            }
sub sortkey          { return $_[0]->{'sortkey'};          }
sub is_active        { return $_[0]->{'is_active'};        }

sub tracking_flag {
    my ($self) = @_;
    return $self->{'tracking_flag'} if exists $self->{'tracking_flag'};
    $self->{'tracking_flag'} = Bugzilla::Extension::TrackingFlags::Flag->new($self->tracking_flag_id);
    return $self->{'tracking_flag'};
}

sub setter_group {
    my ($self) = @_;
    return $self->{'setter_group'} if exists $self->{'setter_group'};
    $self->{'setter_group'} = Bugzilla::Group->new($self->setter_group_id);
    return $self->{'setter_group'};
}

1;
