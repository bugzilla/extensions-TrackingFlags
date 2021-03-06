# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::TrackingFlags;

use strict;

use base qw(Bugzilla::Extension);

use Bugzilla::Extension::TrackingFlags::Constants;
use Bugzilla::Extension::TrackingFlags::Flag;
use Bugzilla::Extension::TrackingFlags::Flag::Bug;
use Bugzilla::Extension::TrackingFlags::Flag::Value;
use Bugzilla::Extension::TrackingFlags::Flag::Visibility;
use Bugzilla::Extension::TrackingFlags::Admin;

use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Field;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Error;
use Bugzilla::Extension::BMO::Data;
use Bugzilla::Install::Util qw(indicate_progress);

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

        $vars->{tracking_flag_types} = FLAG_TYPES;
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

        $vars->{tracking_flag_types} = FLAG_TYPES;
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
            type => {
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

sub install_update_db {
    my $dbh = Bugzilla->dbh;

    return; # XXX remove this to run the migration

    # Migrate old custom field based tracking flags to the new
    # table based tracking flags

    my %bmo_tracking_flags 
        = %{$Bugzilla::Extension::BMO::Data::cf_visible_in_products};
    my @bmo_project_flags
        = @{$Bugzilla::Extension::BMO::Data::cf_project_flags};

    my $fields = Bugzilla::Field->match({ custom => 1, 
                                          type   => FIELD_TYPE_SINGLE_SELECT });
    LAST: foreach my $field (@$fields) {
        next if $field->name !~ /^cf_(blocking|tracking|status)_/;
        foreach my $field_re (keys %bmo_tracking_flags) {
            next if $field->name !~ $field_re;

            # Create the new tracking flag if not exists
            my $new_flag 
                    = Bugzilla::Extension::TrackingFlags::Flag->new({ name => $field->name });

            next if $new_flag;
                    
            print "Migrating custom tracking field " . $field->name . "\n";

            my $new_flag_name = $field->name . "_new"; # Temporary name til we delete the old

            my $type =
                grep($field->name =~ $_, @bmo_project_flags)
                    ? 'tracking'
                    : 'project';

            $dbh->bz_start_transaction();

            $new_flag = Bugzilla::Extension::TrackingFlags::Flag->create({
                name        => $new_flag_name,
                description => $field->description,
                type        => $type, 
                sortkey     => $field->sortkey, 
            });

            _migrate_flag_visibility($new_flag, $field_re, %bmo_tracking_flags);

            _migrate_flag_values($new_flag, $field);

            _migrate_flag_bugs($new_flag, $field);

            _migrate_flag_activity($new_flag, $field);

            # Set all old custom field values to '---'
            $dbh->do("UPDATE bugs SET " . $field->name . " = '---'");
    
            # Remove the old custom field
            $field->set_obsolete(1);
            $field->remove_from_db();
                 
            # Rename the new flag
            $dbh->do("UPDATE fielddefs SET name = ? WHERE name = ?",
                     undef, $field->name, $new_flag_name);
            $new_flag->set_name($field->name);
            $new_flag->update;

            $dbh->bz_commit_transaction();

            last LAST; # XXX comment this if you want to do more than one
        }
    }
}

sub _migrate_flag_visibility {
    my ($new_flag, $field_re, %bmo_tracking_flags) = @_;

    my %product_cache;
    my %component_cache;

    # Create product/component visibility
    foreach my $prod_name (keys %{ $bmo_tracking_flags{$field_re} }) {
        $product_cache{$prod_name} ||= Bugzilla::Product->new({ name => $prod_name });
        $product_cache{$prod_name} || next; # die "No such product $prod_name\n";

        # If no components specified then we do Product/__any__
        # otherwise, we enter an entry for each Product/Component
        my $components = $bmo_tracking_flags{$field_re}{$prod_name};
        if (!@$components) {
            Bugzilla::Extension::TrackingFlags::Flag::Visibility->create({
                tracking_flag_id => $new_flag->id,
                product_id       => $product_cache{$prod_name}->id, 
                component_id     => undef
            });
        }
        else {
            foreach my $comp_name (@$components) {
                $component_cache{"${prod_name}:${comp_name}"} 
                    ||= Bugzilla::Component->new({ name    => $comp_name, 
                                                   product => $product_cache{$prod_name} });
                $component_cache{"${prod_name}:${comp_name}"}
                    || next; # die "No such product $prod_name and component $comp_name\n";
                Bugzilla::Extension::TrackingFlags::Flag::Visibility->create({
                    tracking_flag_id => $new_flag->id,
                    product_id       => $product_cache{$prod_name}->id, 
                    component_id     => $component_cache{"${prod_name}:${comp_name}"}->id, 
                });
            }
        }
    }
}

sub _migrate_flag_values {
    my ($new_flag, $field) = @_;

    my %blocking_trusted_requesters 
        = %{$Bugzilla::Extension::BMO::Data::blocking_trusted_requesters};
    my %blocking_trusted_setters
        = %{$Bugzilla::Extension::BMO::Data::blocking_trusted_setters};
    my %status_trusted_wanters 
        = %{$Bugzilla::Extension::BMO::Data::status_trusted_wanters};
    my %status_trusted_setters 
        = %{$Bugzilla::Extension::BMO::Data::status_trusted_setters};

    my %group_cache;
    foreach my $value (@{ $field->legal_values }) {
        my $group_name = 'everyone';

        if ($field->name =~ /^cf_(blocking|tracking)_/) {
            if ($value->name ne '---' && $value->name ne '?') {
                $group_name = _get_setter_group($field->name, \%blocking_trusted_setters);
            }
            if ($value->name eq '?') {
                $group_name = _get_setter_group($field->name, \%blocking_trusted_requesters);
            }
        } elsif ($field->name =~ /^cf_status_/) {
            if ($value->name eq 'wanted') {
                $group_name = _get_setter_group($field->name, \%status_trusted_wanters);
            } elsif ($value->name ne '---' && $value->name ne '?') {
                $group_name = _get_setter_group($field->name, \%status_trusted_setters);
            }
        }
   
        $group_cache{$group_name} ||= Bugzilla::Group->new({ name => $group_name });
        $group_cache{$group_name} || die "Setter group '$group_name' does not exist";

        Bugzilla::Extension::TrackingFlags::Flag::Value->create({
            tracking_flag_id => $new_flag->id, 
            value            => $value->name,
            setter_group_id  => $group_cache{$group_name}->id,  
        });
    }
}

sub _get_setter_group {
    my ($field, $trusted) = @_;
    my $setter_group = $trusted->{'_default'} || "";
    foreach my $dfield (keys %$trusted) {
        if ($field =~ $dfield) {
            $setter_group = $trusted->{$dfield};
        }
    }
    return $setter_group;
}

sub _migrate_flag_bugs {
    my ($new_flag, $field) = @_;
    my $dbh = Bugzilla->dbh;

    my $bugs = $dbh->selectall_arrayref("SELECT bug_id, " . $field->name . " 
                                           FROM bugs 
                                          WHERE " . $field->name . " != '---'
                                       ORDER BY bug_id");

    my $count = 1;
    my $total = scalar @$bugs;
    foreach my $row (@$bugs) {
        my ($id, $value) = @$row;
        indicate_progress({ current => $count++, total => $total, every => 25 });
        Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
            tracking_flag_id => $new_flag->id, 
            bug_id           => $id, 
            value            => $value, 

        });
    }
}

sub _migrate_flag_activity {
     my ($new_flag, $field) = @_;
     my $dbh = Bugzilla->dbh;

     my $new_field = Bugzilla::Field->new({ name => $new_flag->name });
     $dbh->do("UPDATE bugs_activity SET fieldid = ? WHERE fieldid = ?",  
              undef, $new_field->id, $field->id);
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
            if (!$flag->can_set_value($value->value)) {
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
        my $old_value = $flag->bug_flag ? $flag->bug_flag->value : '---';
        
        next if $new_value eq $old_value;

        if ($new_value ne $old_value) {
            # Do not allow if the user cannot set the old value or the new value
            if (!$flag->can_set_value($new_value, $old_value)) {
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
            $flag->bug_flag->remove_from_db();
        }
        elsif ($removed eq '---') {
            Bugzilla::Extension::TrackingFlags::Flag::Bug->create({
                tracking_flag_id => $flag->id,
                bug_id           => $bug->id,
                value            => $added,
            });
        }
        else {
            $flag->bug_flag->set_value($added);
            $flag->bug_flag->update($timestamp);
        }

        $changes->{$flag->name} = [ $removed, $added ];
        LogActivityEntry($bug->id, $flag->name, $removed, $added, $user->id, $timestamp);
    }
}

__PACKAGE__->NAME;
