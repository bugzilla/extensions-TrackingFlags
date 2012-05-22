package Bugzilla::Extension::TrackingFlags::Constants;

use strict;
use base qw(Exporter);

our @EXPORT = qw(
    FLAG_TYPES
);

use constant FLAG_TYPES => [
    {
        name        => 'tracking',
        description => 'Tracking Flags',
        collapsed   => 1,
    },
    {
        name        => 'project',
        description => 'Project Flags',
        collapsed   => 0,
    },
];

1;
