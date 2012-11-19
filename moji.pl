#!/usr/bin/perl
# http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC.pm

# The latest version of this script may not be tested; use at your own risk.

use warnings;
use strict;

use Moji::IRC;    # IRC helper, mostly for anti-highlighting.
use Moji::Plugin; # Plugins.

#autoload plugins from Moji::Plugin namespace

Moji::Plugin::load_all();

Moji::Plugin::enable_all();

# Create and run the POE session.
Moji::IRC::run();

Moji::Plugin::destroy_all();

exit 0;

