# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Extension::TrackingFlags::Admin;

our $VERSION = '1';

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{'page_id'};
    my $vars = $args->{'vars'};

    if ($page eq 'tracking_flags_admin_list.html') {
        Bugzilla->user->in_group('admin')
            || ThrowUserError('auth_failure',
                              { group  => 'admin',
                                action => 'access',
                                object => 'administrative_pages' });
        admin_list($vars);

    } elsif ($page eq 'tracking_flags_admin_edit.html') {
        Bugzilla->user->in_group('admin')
            || ThrowUserError('auth_failure',
                              { group  => 'admin',
                                action => 'access',
                                object => 'administrative_pages' });
        admin_edit($vars);
    }
}

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    $args->{'schema'}->{'tracking_flags'} = {
        FIELDS => [
            id => {
                TYPE       => 'MEDIUMSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            name => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
            description => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
            sortkey => {
                TYPE    => 'INT2',
                NOTNULL => 1,
                DEFAULT => '0', 
            },
            is_active => {
                TYPE    => 'BOOLEAN',
                NOTNULL => 1,
                DEFAULT => 'TRUE',
            },
        ],
    };
    $args->{'schema'}->{'tracking_flags_values'} = {
        FIELDS => [
            id => {
                TYPE       => 'MEDIUMSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            tracking_flag_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'tracking_flags',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            setter_group_id => {
                TYPE       => 'INT3',
                NOTNULL    => 0,
                REFERENCES => {
                    TABLE  => 'groups',
                    COLUMN => 'id',
                    DELETE => 'SET NULL',
                },
            },
            value => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
            sortkey => {
                TYPE    => 'INT2',
                NOTNULL => 1,
                DEFAULT => '0', 
            },
            is_active => {
                TYPE    => 'BOOLEAN',
                NOTNULL => 1,
                DEFAULT => 'TRUE',
            },
        ],
    };
    $args->{'schema'}->{'tracking_flags_bugs'} = {
        FIELDS => [
            id => {
                TYPE       => 'MEDIUMSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            tracking_flag_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'tracking_flags',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            bug_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'bugs',
                    COLUMN => 'bug_id',
                    DELETE => 'CASCADE',
                },
            },
            value => {
                TYPE    => 'varchar(64)',
                NOTNULL => 1,
            },
        ],
    };
    $args->{'schema'}->{'tracking_flags_visibility'} = {
        FIELDS => [
            id => {
                TYPE       => 'MEDIUMSERIAL',
                NOTNULL    => 1,
                PRIMARYKEY => 1,
            },
            tracking_flag_id => {
                TYPE       => 'INT3',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'tracking_flags',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            product_id => {
                TYPE       => 'INT2',
                NOTNULL    => 1,
                REFERENCES => {
                    TABLE  => 'products',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            component_id => {
                TYPE       => 'INT2',
                NOTNULL    => 0,
                REFERENCES => {
                    TABLE  => 'components',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
        ],
    };
    # TODO indices
}

__PACKAGE__->NAME;
