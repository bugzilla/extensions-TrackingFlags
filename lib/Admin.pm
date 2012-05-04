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
use JSON;

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

    $vars->{groups} = _groups_to_json();

    if (exists $input->{edit}) {
        $vars->{mode} = 'edit';
        $vars->{flag} = Bugzilla::Extension::TrackingFlags::Flag->new($input->{edit})
            || ThrowCodeError('tracking_flags_invalid', { what => 'flag' });
        $vars->{flag_values} = _flag_values_to_json($vars->{flag});
        $vars->{flag_visibility} = _flag_visibility_to_json($vars->{flag});

    } elsif (exists $input->{copy}) {
        $vars->{mode} = 'copy';

    } else {
        $vars->{mode} = 'new';
    }
}

sub _groups_to_json {
    my @data;
    foreach my $group (Bugzilla::Group->get_all()) {
        push @data, {
            id   => $group->id,
            name => $group->name,
        };
    }
    return encode_json(\@data);
}

sub _flag_values_to_json {
    my ($flag) = @_;
    my @data;
    foreach my $value (@{$flag->values}) {
        push @data, {
            id              => $value->id,
            value           => $value->value,
            setter_group_id => $value->setter_group_id,
            is_active       => $value->is_active ? JSON::true : JSON::false,
        };
    }
    return encode_json(\@data);
}

sub _flag_visibility_to_json {
    my ($flag) = @_;
    my @data;
    foreach my $visibility (@{$flag->visibility}) {
        push @data, {
            id        => $visibility->id,
            product   => $visibility->product->name,
            component => $visibility->component_id ? $visibility->component->name : undef,
        };
    }
    @data = sort {
                lc($a->{product}) cmp lc($b->{product})
                || lc($a->{component}) cmp lc($b->{component})
            } @data;
    return encode_json(\@data);
}

1;
