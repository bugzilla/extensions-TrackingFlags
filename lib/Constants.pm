package Bugzilla::Extension::TrackingFlags::Constants;

use strict;
use base qw(Exporter);

our @EXPORT = qw(
    VALID_FLAG_TYPES
);

use constant VALID_FLAG_TYPES => qw(
    blocking
    status
    project
);

1;
