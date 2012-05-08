# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Extension::TrackingFlags::Flag::Bug;
use Bugzilla::Extension::TrackingFlags::Flag;
use Bugzilla::Extension::TrackingFlags::Admin;

use Bugzilla::Bug;
use Bugzilla::Error;

use Data::Dumper;

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

sub template_before_process {
    my ($self, $args) = @_;
    my $file = $args->{'file'};
    my $vars = $args->{'vars'};

    if ($file eq 'bug/create/create.html.tmpl') {
        $vars->{'new_tracking_flags'} = Bugzilla::Extension::TrackingFlags::Flag->match({
            product   => $vars->{'product'}->name,
            is_active => 1,
        });
    }
    
    if ($file eq 'bug/edit.html.tmpl') {
        # note: bug/edit.html.tmpl doesn't support multiple bugs
        my $bug = exists $vars->{'bugs'} ? $vars->{'bugs'}[0] : $vars->{'bug'};

        $vars->{'new_tracking_flags'} = Bugzilla::Extension::TrackingFlags::Flag->match({
            product     => $bug->product, 
            component   => $bug->component, 
            bug_id      => $bug->id,
            is_active   => 1, 
            include_set => 1, 
        });  
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
        foreach my $value (@{$flag->values}) {
            next if $value->value ne $params->{$flag->name};
            if (!grep($_ eq $params->{$flag->name}, @{$flag->allowable_values})) {
                ThrowUserError('tracking_flags_change_denied', 
                               { flag => $flag, value => $value });
            }
            Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
                tracking_flag_id => $flag->id, 
                bug_id           => $bug->id,
                value            => $value->value, 
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

    my $tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->match({ 
        bug_id           => $bug->id, 
        is_active_or_set => 1 
    });

    my @updated;
    foreach my $flag (@$tracking_flags) {
        next if !$params->{$flag->name};
        my $new_value = $params->{$flag->name};
        my $old_value = $flag->set_flag->value;
        next if $new_value eq $old_value;
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

    if (@updated) {
        foreach my $change (@updated) {
            my $flag    = $change->{'flag'};
            my $added   = $change->{'added'};
            my $removed = $change->{'removed'};
            $flag->set_flag->set_value($added);
            $flag->set_flag->update($timestamp);
            $changes->{$flag->name} = [ $removed, $added ];
            LogActivityEntry($bug->id, $flag->name, $removed, $added, $user->id, $timestamp);
        }
    }
}

__PACKAGE__->NAME;
