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
    my $dbh = Bugzilla->dbh;
    my @tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->get_all;
    foreach my $flag (@tracking_flags) {
        my $sql = "(SELECT tracking_flags_bugs.value " . 
                  "   FROM tracking_flags JOIN tracking_flags_bugs " .
                  "        ON tracking_flags.id = tracking_flags_bugs.tracking_flag_id " .
                  "  WHERE tracking_flags.name = " . $dbh->quote($flag->name) .
                  "        AND tracking_flags_bugs.bug_id = bugs.bug_id)";
        $columns->{$flag->name} = { 
            name  => $sql,
            title => $flag->description
        };
    }
}

sub search_operator_field_override {
    my ($self, $args) = @_;
    my $operators = $args->{'operators'};

    my @tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->get_all;
    foreach my $flag (@tracking_flags) {
        $operators->{$flag->name} = {
            _non_changed => sub { 
                _tracking_flags_search_nonchanged($flag->name, @_) 
            }
        };
    }
}

sub _tracking_flags_search_nonchanged {
    my $flag_name = shift;
    my $self      = shift;
    my %func_args = @_;
    my ($t, $chartid, $supptables, $ff) =
        @func_args{qw(t chartid supptables ff)};
    my $dbh = Bugzilla->dbh;

    return if ($$t =~ m/^changed/);

    my $bugs_alias  = "tracking_flags_bugs_$$chartid";
    my $flags_alias = "tracking_flags_$$chartid";

    push(@$supptables, "LEFT JOIN tracking_flags_bugs AS $bugs_alias " .
                       "ON bugs.bug_id = $bugs_alias.bug_id");
    push(@$supptables, "LEFT JOIN tracking_flags AS $flags_alias " .
                       "ON $bugs_alias.tracking_flag_id = $flags_alias.id " .
                       "AND $flags_alias.name = " . $dbh->quote($flag_name));
    
    $$ff = "$bugs_alias.value";
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
            next if $value->value eq '---'; # do not insert if value is '---', same as empty
            if (!grep($_ eq $value->value, @{$flag->allowable_values})) {
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

    # Do not filter by product/component as we may be changing those
    my $tracking_flags = Bugzilla::Extension::TrackingFlags::Flag->match({
        bug_id    => $bug->id, 
        is_active => 1, 
    });

    my (@flag_changes);
    foreach my $flag (@$tracking_flags) {
        my $new_value = $params->{$flag->name} || '---';
        my $old_value = $flag->set_flag ? $flag->set_flag->value : '---';
        
        next if $new_value eq $old_value;

        if ($new_value ne $old_value) {
            # Do not allow if the user cannot set the old value or the new value
            if (!grep($_ eq $old_value, @{$flag->allowable_values})
                || !grep($_ eq $new_value, @{$flag->allowable_values})) 
            {
                 ThrowUserError('tracking_flags_change_denied',
                                { flag => $flag, value => $new_value });
            } 
            push(@flag_changes, { flag    => $flag, 
                                  added   => $new_value, 
                                  removed => $old_value });
        }
    }

    foreach my $change (@flag_changes) {
        my $flag    = $change->{'flag'};
        my $added   = $change->{'added'};
        my $removed = $change->{'removed'};

        if ($added eq '---') {
            $flag->set_flag->remove_from_db();
        }
        elsif ($removed eq '---') {
            Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
                tracking_flag_id => $flag->id,
                bug_id           => $bug->id,
                value            => $added,
            });
        }
        else {
            $flag->set_flag->set_value($added);
            $flag->set_flag->update($timestamp);
        }

        $changes->{$flag->name} = [ $removed, $added ];
        LogActivityEntry($bug->id, $flag->name, $removed, $added, $user->id, $timestamp);
    }
}

__PACKAGE__->NAME;
