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

use Bugzilla::Bug;

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

sub buglist_columns {
    my ($self,  $args) = @_;
    my $columns = $args->{columns};
    my @tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->get_all;
    foreach my $flag (@tracking_flags) {
        $columns->{$flag->description} = { name => $flag->name };
    }
}

sub bug_end_of_create {
    my ($self, $args) = @_;
    my $bug        = $args->{'bug'};
    my $timestamp  = $args->{'timestamp'};
    my $params     = Bugzilla->input_params;
    my $user       = Bugzilla->user;

    my $tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->match({
        product   => $bug->product, 
        component => $bug->component, 
        is_active => 1, 
    });
    
    foreach my $flag (@$tracking_flags) {
        next if !$params->{$flag->name};
        next if $params->{$flag->name} eq '---';
        foreach my $value (@{$flag->values}) {
            next if $value->name ne $params->{$flag->name};
            if (!grep($_ eq $params->{$flag->name}, @{$flag->allowable_values})) {
                ThrowUserError('tracking_flags_change_denied', 
                               { flag => $flag, value => $value });
            }
            Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
                tracking_flag_id => $flag->id, 
                bug_id           => $bug->id,
                value            => $value->name, 
            });
        }
    }
}

sub bug_end_of_update {
    my ($self, $args) = @_;
    my $bug       = $args->{'bug'};
    my $timestamp = $args->{'timestamp'};
    my $changes   = $args->{'changes'};
    my $params    = Bugzilla->input_params;
    my $user      = Bugzilla->user;

    my $bug_flags 
        = Bugzilla::Extension::TrackingFlags::Flag::Bug->match({ bug_id => $bug->id });

    my (@added, @removed, @updated);
    foreach my $flag (@$bug_flags) {
        next if !$params->{$flag->tracker_flag->name};
        my $new_value = $params->{$flag->tracker_flag->name};
        my $old_value = $flag->value;
        next if $new_value eq $old_value;
        if ($new_value ne $old_value && $new_value eq '---') {
            # Do not allow if the user cannot set the old value
            if (!grep($_ eq $old_value, @{$flag->allowable_values})) {
                 ThrowUserError('tracking_flags_change_denied', 
                                { flag => $flag, value => $new_value });
            } 
            push(@removed, $flag);
        }
        if ($new_value ne $old_value) {
            # Do not allow if the user cannot set the old value or the new value
            if (!grep($_ eq $old_value, @{$flag->allowable_values})
                || !grep($_ eq $new_value, @{$flag->allowable_values})) 
            {
                 ThrowUserError('tracking_flags_change_denied',
                                { flag => $flag, value => $new_value });
            } 
            push(@updated, { flag    => $flag, 
                             added   => $new_value, 
                             removed => $old_value });
        }
    }

    my $tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->match({
        product   => $bug->product,
        component => $bug->component,
        is_active => 1, 
    });
   
    foreach my $flag (@$tracking_flags) {
        next if !$params->{$flag->name};
        next if $params->{$flag->name} eq '---';
        foreach my $value (@{$flag->values}) {
            next if $value->name ne $params->{$flag->name};
            if (!grep($_ eq $params->{$flag->name}, @{$flag->allowable_values})) {
                ThrowUserError('tracking_flags_change_denied', 
                               { flag => $flag, value => $value });
            }
            if ($value->setter_group && !$user->in_group($value->setter_group->name)) {
                ThrowUserError('tracking_flags_change_denied', 
                               { flag => $flag, value => $value });
            }
            push(@added, { flag => $flag, added => $value->name });
        }
    }

    if (@added || @removed || @updated) {
        foreach my $change (@added) {
            Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
                tracking_flag_id => $change->{'flag'}->id,
                bug_id           => $bug->id,
                value            => $change->{'added'},
            });
            $changes->{$change->{'flag'}->tracking_flag->name} = ['', $change->{'added'}];
            LogActivityEntry($bug->id, $change->{'flag'}->tracking_flag->name, '', 
                             $change->{'added'}, $user->id, $timestamp);
        }

        foreach my $change (@removed) {
            $change->{'flag'}->remove_from_db();
            $changes->{$change->{'flag'}->tracking_flag->name} = [$change->{'removed'}, ''];
            LogActivityEntry($bug->id, $change->{'flag'}->tracking_flag->name, 
                             $change->{'removed'}, '', $user->id, $timestamp);
        }

        foreach my $change (@updated) {
            $change->{'flag'}->set_value($change->{'added'});
            $change->{'flag'}->update($timestamp);
            $changes->{$change->{'flag'}->tracking_flag->name} = [$change->{'removed'}, $change->{'added'}];
            LogActivityEntry($bug->id, $change->{'flag'}->tracking_flag->name, $change->{'removed'}, 
                             $change->{'added'}, $user->id, $timestamp);
        }
    }
}

__PACKAGE__->NAME;
