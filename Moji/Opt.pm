package Moji::Opt;

use strict;
use warnings;

use MIME::Base64;


# positional command line arguments

use constant OPT_IRC_OP => 0;
use constant OPT_JIRA_NAME => 1;
use constant OPT_JIRA_PASS => 2;
use constant OPT_IRC_NICK => 3;
use constant OPT_IRC_USER => 4;
use constant OPT_IRC_PASS => 5;

# Bot default identification:
our $bot_info = {
  Nick     => 'moji2',
  Username => 'Moji',
  Ircname  => 'MojiBot',
  Server   => 'irc.esper.net',
  Port     => '6667',
};

# JIRA root URL.
our $root_path = "https://mojang.atlassian.net";

# JIRA browse URL.
our $browse_path = "$root_path/browse";

# JIRA rest api URL.
our $json_path = "$root_path/rest/api/latest";

# JIRA atom feed URL.
our $feed_path = "$root_path/activity?streams=user+NOT+biff";

# Bot can tell us where to find its source, not used for anything else.
our $bot_source_url = "https://github.com/gitbuh/moji";

# For !search command
our $max_search_results = 5;

# Minimum number of seconds between feed checks.
# Interval is increased by this amount when there is no activity.
our $tick_interval_min = 5;

# Maximum number of seconds between feed checks.
our $tick_interval_max = 300; 

# IRC admin user (passed in at runtime)
our $op_nick;

# Bot IRC nick (passed in at runtime)
our $irc_nick;

# Bot IRC user (passed in at runtime)
our $irc_user;

# Bot IRC password (passed in at runtime)
our $irc_pass;


#base64-encoded JIRA username:password (passed in at runtime)
our $jira_credentials;

# Needs at least two arguments
if (@ARGV <= OPT_JIRA_NAME) {

  print "
    usage: $0 <op_nick> <jira_username> [jira_password] [irc_nick] [irc_user irc_pass]\n\n";

}

# Get operator irc nick if not provided as argument
if (@ARGV <= OPT_IRC_OP) {

  print "
Enter the bot operator's IRC nick: ";
    
  chomp ($ARGV[OPT_IRC_OP] = <STDIN>);
  $ARGV[OPT_IRC_OP] or die "Operator nick is required";
  
  print "\n";

}
print 'Operator:  '. $ARGV[OPT_IRC_OP] . "\n"; 


# Get username if not provided as argument
if (@ARGV <= OPT_JIRA_NAME) {

  print "
Enter your JIRA username: ";
    
  chomp ($ARGV[OPT_JIRA_NAME] = <STDIN>);
  $ARGV[OPT_JIRA_NAME] or die "JIRA username is required";
  
  print "\n";

}
print 'JIRA user: '. $ARGV[OPT_JIRA_NAME] . "\n"; 


# Get password if not provided as argument
if (@ARGV <= OPT_JIRA_PASS) {

  print "
Enter your JIRA password: ";
    
  system('stty','-echo');
  chomp ($ARGV[OPT_JIRA_PASS] = <STDIN>);
  system('stty','echo');
  $ARGV[OPT_JIRA_PASS] or die "JIRA password is required";
  
  print "\n";

}

# Get bot's irc nick if not provided as argument
if (@ARGV <= OPT_IRC_NICK) {

  print "
Enter the bot's IRC nick (leave blank for \"$bot_info->{Nick}\"): ";
    
  chomp ($ARGV[OPT_IRC_NICK] = <STDIN>);
  $ARGV[OPT_IRC_NICK] or $ARGV[OPT_IRC_NICK] = $bot_info->{Nick};
  
  print "\n";

}
print 'IRC nick:  '. $ARGV[OPT_IRC_NICK] . "\n"; 

# Get bot's irc nick if not provided as argument
if (@ARGV <= OPT_IRC_USER) {

  print "
Enter the IRC user to identify as (leave blank for \"$ARGV[OPT_IRC_OP]\"): ";
    
  chomp ($ARGV[OPT_IRC_USER] = <STDIN>);
  $ARGV[OPT_IRC_USER] or $ARGV[OPT_IRC_USER] = $ARGV[OPT_IRC_OP];
  
  print "\n";

}
print 'IRC user:  '. $ARGV[OPT_IRC_USER] . "\n"; 

# Get bot's irc pass if not provided as argument
if (@ARGV <= OPT_IRC_PASS && length $ARGV[OPT_IRC_USER]) {

  print "
Enter the IRC password (leave blank to skip nickserv identify): ";
    
  system('stty','-echo');
  chomp ($ARGV[OPT_IRC_PASS] = <STDIN>);
  system('stty','echo');
  
  print "\n";

}

$op_nick = $ARGV[0];
$jira_credentials = encode_base64(
    $ARGV[OPT_JIRA_NAME] . ':' . $ARGV[OPT_JIRA_PASS]
);
$irc_nick = $ARGV[OPT_IRC_NICK] || $bot_info->{Nick};
$irc_user = $ARGV[OPT_IRC_USER];
$irc_pass = $ARGV[OPT_IRC_PASS];

$bot_info->{Nick} = $irc_nick;



1;
