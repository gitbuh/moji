#!/usr/bin/perl
# http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC.pm

# The latest version of this script may not be tested; use at your own risk.

use warnings;
use strict;

#use Moji::Cmd;    # Bot commands.
use Moji::IRC;    # IRC helper, mostly for anti-highlighting.
use Moji::Jira;   # Jira helper.
use Moji::Net;    # Make HTTPS requests, get json and xml as hash, etc.
use Moji::Opt;    # Options and settings.
use Moji::Time;   # Date / time parsing, fuzzy formatting, etc.

use Moji::Plugin::Feed;
use Moji::Plugin::Op;
use Moji::Plugin::Search;

use HTML::Strip;
use POE;
use POE::Component::IRC;
use MIME::Base64;

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


# All your base64 encoded JIRA logins are belong to us
my %auth = ( ${Moji::Opt::op_nick} => ${Moji::Opt::jira_credentials} );

Moji::Plugin::Feed->enable();
Moji::Plugin::Op->enable();
Moji::Plugin::Search->enable();

# Create and run the POE session.
#    bot_tick    => \&on_tick,
Moji::IRC::run();
exit 0;

