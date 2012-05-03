# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags::Flag::Bug;

use base qw(Bugzilla::Object);

use strict;
use warnings;

use Bugzilla::Bug;
use Bugzilla::Error;
use Scalar::Util qw(blessed);

###############################
####    Initialization     ####
###############################

use constant DB_TABLE => 'tracking_flags_bug';

use constant DB_COLUMNS => qw(
    id
    tracking_flag_id
    bug_id
    value
);

use constant LIST_ORDER => 'id';

use constant UPDATE_COLUMNS => qw(
    value
);

use constant VALIDATORS => {
    tracking_flag_id => \&_check_tracking_flag,
    value            => \&_check_value,
};

###############################
####      Validators       ####
###############################

sub _check_value {
    my ($invocant, $value) = @_;
    $value || ThrowCodeError('param_required', { param => 'value' });
    return $value;
}

sub _check_tracking_flag {
    my ($invocant, $flag) = @_;
    if (blessed $flag) {
        return $flag->id;
    }
    $flag = Bugzilla::Extension::TrackingFlags::Flag->new($flag)
        || ThrowCodeError('tracking_flags_invalid_param', { name => 'flag_id', value => $flag });
    return $flag->id;
}

###############################
####       Setters         ####
###############################

sub set_value        { $_[0]->set('value', $_[1]);           }

###############################
####      Accessors        ####
###############################

sub tracking_flag_id { return $_[0]->{'tracking_flag_id'}; }
sub bug_id           { return $_[0]->{'bug_ud'};           }
sub value            { return $_[0]->{'value'};            }

sub bug {
    my ($self) = @_;
    $self->{'bug'} ||= Bugzilla::Bug->new($self->bug_id);
    return $self->{'bug'};
}

1;
