#!/usr/bin/perl
# http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC.pm

# The latest version of this script may not be tested; use at your own risk.

use warnings;
use strict;

use Moji::IRC;    # IRC helper, mostly for anti-highlighting.
use Moji::Opt;    # Options and settings.
use Moji::Plugin; # Plugins.

use MIME::Base64;

#autoload plugins from Moji::Plugin namespace

my $plugins = Moji::Plugin::load( qw/ AntiHighlight Feed Op Search TicketKey / );

# Needs at least two arguments
if (@ARGV < 2) {

  print "
    IRC bot operator nick and JIRA user name are required.
    usage: $0 <op_nick> <jira_username> [jira_password]\n\n";
  exit 1;

}

# Get password if not provided as argument
if (@ARGV < 3) {

  print "
    Enter your JIRA password: ";
    
  system('stty','-echo');
  $ARGV[2] = <STDIN>;
  system('stty','echo');
  
  print "\n\n";

}

# IRC admin user
${Moji::Opt::op_nick} = $ARGV[0];

#base64-encoded JIRA username:password
${Moji::Opt::jira_credentials} = encode_base64($ARGV[1] . ':' . $ARGV[2]);


Moji::Plugin::setup_all();

Moji::Plugin::enable_all();

# Create and run the POE session.
#    bot_tick    => \&on_tick,
Moji::IRC::run();

Moji::Plugin::teardown_all();

exit 0;

