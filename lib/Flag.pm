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

use Bugzilla::Error;
use Bugzilla::Extension::TrackingFlags::Flag::Value;
use Bugzilla::Extension::TrackingFlags::Flag::Visibility;
use Bugzilla::Util qw(detaint_natural);

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
####      Validators       ####
###############################

sub _check_name {
    my ($invocant, $name) = @_;
    $name || ThrowCodeError('param_required', { param => 'name' });
    return $name;
}

sub _check_description {
    my ($invocant, $description) = @_;
    $description || ThrowCodeError( 'param_required', { param => 'description' } );
    return $description;
}

sub _check_sortkey {
    my ($invocant, $sortkey) = @_;
    detaint_natural($sortkey)
        || ThrowUserError('field_invalid_sortkey', { sortkey => $sortkey });
    return $sortkey;
}

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

sub name        { return $_[0]->{'name'};        }
sub description { return $_[0]->{'description'}; }
sub sortkey     { return $_[0]->{'sortkey'};     }
sub is_active   { return $_[0]->{'is_active'};   }

sub values {
    my ($self) = @_;
    $self->{'values'} ||= Bugzilla::Extension::TrackingFlags::Flag::Value->match({ 
        tracking_flag_id => $self->id
    });
    return $self->{'values'};
}

sub visibility {
    my ($self) = @_;
    $self->{'visibility'} ||= Bugzilla::Extension::TrackingFlags::Flag::Visibility->match({
        tracking_flag_id => $self->id
    });
    return $self->{'visibility'};
}

1;
