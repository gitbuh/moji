package Moji::Opt;

use strict;
use warnings;

use MIME::Base64;

# Bot identifies itself on IRC as:
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
our $feed_path = "$root_path/activity";

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

#base64-encoded JIRA username:password (passed in at runtime)
our $jira_credentials;


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
$op_nick = $ARGV[0];

#base64-encoded JIRA username:password
$jira_credentials = encode_base64($ARGV[1] . ':' . $ARGV[2]);

1;
