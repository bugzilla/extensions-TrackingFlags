package Bugzilla::Extension::TrackingFlags::Constants;

use strict;
use base qw(Exporter);

our @EXPORT = qw(
    FLAG_TYPES
);

use constant FLAG_TYPES => (
    {
        name    => 'blocking', 
        sortkey => 30,
    },
    {
        name    => 'status', 
        sortkey => 20, 
    }, 
    {
        name    => 'project', 
        sortkey => 10,
    },
);

1;
