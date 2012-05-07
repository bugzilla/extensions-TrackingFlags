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

sub match {
    my $class = shift;
    my ($params) = @_;

    if ($params->{'component'} || $params->{'component_id'}
        || $params->{'product'} || $params->{'product_id'}) 
    {
        use Data::Dumper; print STDERR Dumper $params;
        my $visible_flags 
            = Bugzilla::Extension::TrackingFlags::Flag::Visibility->match(@_);
        my @flag_ids = map { $_->tracking_flag_id } @$visible_flags;
        
        delete $params->{'component'} if exists $params->{'component'};
        delete $params->{'component_id'} if exists $params->{'component_id'};
        delete $params->{'product'} if exists $params->{'product'};
        delete $params->{'product_id'} if exists $params->{'product_id'};

        $params->{'id'} = \@flag_ids;
    }

    use Data::Dumper; print STDERR Dumper $params;

    return $class->SUPER::match(@_);
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
    # XXX ensure name starts with cf_
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
    use Data::Dumper; print STDERR Dumper $self->{'values'};
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
    foreach my $value (@{$self->{'values'}}) {
        if (!$value->setter_group_id 
            || $user->in_group($value->setter_group->name))
        {
            push(@{$self->{'allowable_values'}}, $value->name);
        }
    }
    return $self->{'allowable_values'};
}

sub set_flag {
    my ($self, $bug_id) = @_;
    $bug_id ||= $self->{'bug_id'};
    $self->{'set_flag'} 
        ||= Bugzilla::Extension::TrackingFlags::Flag::Bug->new(
            { condition => "tracking_flag_id = ? AND bug_id = ?", 
              values    => [ $self->id, $bug_id ] });
    return $self->{'set_flag'};
}

1;
