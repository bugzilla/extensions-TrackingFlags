# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags::Admin;

use strict;
use warnings;

use Bugzilla;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::Extension::TrackingFlags::Flag;

use base qw(Exporter);
our @EXPORT = qw(
    admin_list
    admin_edit
);

sub admin_list {
    my ($vars) = @_;

    $vars->{flags} = Bugzilla::Extension::TrackingFlags::Flag->match({});
}

sub admin_edit {
    my ($vars, $page) = @_;
    my $input = Bugzilla->input_params;

    $vars->{groups} = [ Bugzilla::Group->get_all() ];

    if (exists $input->{edit}) {
        $vars->{mode} = 'edit';
        $vars->{flag} = Bugzilla::Extension::TrackingFlags::Flag->new($input->{edit})
            || ThrowCodeError('tracking_flags_invalid', { what => 'flag' });

    } elsif (exists $input->{copy}) {
        $vars->{mode} = 'copy';

    } else {
        $vars->{mode} = 'new';
    }
}

1;
