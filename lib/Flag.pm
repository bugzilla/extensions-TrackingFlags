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
use Bugzilla::Constants;
use Bugzilla::Util qw(detaint_natural);

use Bugzilla::Extension::TrackingFlags::Flag::Bug;
use Bugzilla::Extension::TrackingFlags::Flag::Value;
use Bugzilla::Extension::TrackingFlags::Flag::Visibility;

use Data::Dumper;

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
####      Methods          ####
###############################

sub create {
    my $class = shift;
    my ($params) = @_;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    my $flag = $class->SUPER::create(@_);

    # We also have to create an entry for this new flag 
    # in the fielddefs table for use elsewhere. We cannot
    # use Bugzilla::Field->create as it will create the
    # additional tables needed by custom fields which we
    # do not need. Also we do this so as not to add a 
    # another column to the bugs table.
    # We will create the entry as a custom field with a 
    # type of FIELD_TYPE_SINGLE_SELECT 
    $dbh->do("INSERT INTO fielddefs 
             (name, description, sortkey, type, custom, obsolete, buglist)
              VALUES 
             (?, ?, ?, ?, ?, ?, ?)", 
             undef, 
             $flag->name,
             $flag->description,
             $flag->sortkey,
             FIELD_TYPE_SINGLE_SELECT, 
             1, 1, 1);

    $dbh->bz_commit_transaction();
            
    return $flag;
}

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();

    my $old_self = $self->new($self->id);
    my $changes = $self->SUPER::update(@_);
    
    # Update the fielddefs entry
    $dbh->do("UPDATE fielddefs SET name=? WHERE name=?",
             undef,
             $self->name, $old_self->name);

    $dbh->bz_commit_transaction();

    return $changes;
}

sub match {
    my $class = shift;
    my ($params) = @_;

    my $include_set = delete $params->{'include_set'};
    my $bug_id      = delete $params->{'bug_id'};

    print STDERR Dumper $params;

    # Retrieve all existing flags for this bug
    my $set_flags = [];
    if ($include_set && $bug_id) {
        $set_flags = Bugzilla::Extension::TrackingFlags::Flag::Bug->match({ 
            bug_id => $bug_id
        });
    }
   
    # Retrieve all flags relevant for the given product and component 
    if ($params->{'component'} || $params->{'component_id'}
        || $params->{'product'} || $params->{'product_id'}) 
    {
        my $visible_flags 
            = Bugzilla::Extension::TrackingFlags::Flag::Visibility->match(@_);
        my @flag_ids = map { $_->tracking_flag_id } @$visible_flags;
        
        delete $params->{'component'} if exists $params->{'component'};
        delete $params->{'component_id'} if exists $params->{'component_id'};
        delete $params->{'product'} if exists $params->{'product'};
        delete $params->{'product_id'} if exists $params->{'product_id'};

        $params->{'id'} = \@flag_ids;
    }

    my $flags = $class->SUPER::match(@_);

    my %flag_hash = map { $_->id => $_ } @$flags;
    map { $flag_hash{$_->tracking_flag->id} = $_->tracking_flag } @$set_flags 
        if @$set_flags;

    # Prepopulate set_flag if bug_id passed
    if ($bug_id) {
        foreach my $flag (keys %flag_hash) {
            $flag_hash{$flag}->set_flag($bug_id);
        }
    }

    return [ values %flag_hash ];
}

sub remove_from_db {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    $dbh->do('DELETE FROM fielddefs WHERE name = ?', undef, $self->name);
    $self->SUPER::remove_from_db(@_);
    $dbh->bz_commit_transaction();
}

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

sub allowable_values {
    my ($self, $user) = @_;
    $user ||= Bugzilla->user;
    return $self->{'allowable_values'} if exists $self->{'allowable_values'};
    $self->{'allowable_values'} = [];
    foreach my $value (@{$self->values}) {
        if (!$value->setter_group_id 
            || $user->in_group($value->setter_group->name))
        {
            push(@{$self->{'allowable_values'}}, $value->value);
        }
    }
    return $self->{'allowable_values'};
}

sub set_flag {
    # XXX rename to is_set to avoid confusion with this being a setter?
    my ($self, $bug_id) = @_;
    $bug_id ||= $self->{'bug_id'};
    $self->{'bug_id'} = $bug_id;
    $self->{'set_flag'} 
        ||= Bugzilla::Extension::TrackingFlags::Flag::Bug->new(
            { condition => "tracking_flag_id = ? AND bug_id = ?", 
              values    => [ $self->id, $bug_id ] });
    return $self->{'set_flag'};
}

sub has_values {
    my ($self) = @_;
    my $dbh = Bugzilla->dbh;
    return scalar $dbh->selectrow_array("
        SELECT 1
          FROM tracking_flags_bugs
         WHERE tracking_flag_id = ? " .
               $dbh->sql_limit(1),
        undef, $self->id);
}

1;
