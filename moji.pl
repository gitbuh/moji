#!/usr/bin/perl
# http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC.pm

# The latest version of this script may not be tested; use at your own risk.

use warnings;
use strict;

use DateTime::Format::Strptime;
use DateTime::Format::Duration;
use IO::Socket::SSL;
use IO::Socket::INET;
use URI::Escape;
use HTML::Strip;
use XML::Simple;
use JSON;
use POE;
use POE::Component::IRC;
use MIME::Base64;
use Acme::Umlautify;

if (@ARGV < 2) {

  print "
    IRC bot operator nick and JIRA user name are required.
    usage: $0 <op_nick> <jira_username> [jira_password]\n\n";
  exit 1;

}

if (@ARGV < 3) {

  print "
    Enter your JIRA password: ";
    
  system('stty','-echo');
  $ARGV[2] = <STDIN>;
  system('stty','echo');
  
  print "\n\n";

}

# JIRA root URL.
my $root_path = "https://mojang.atlassian.net";

# JIRA browse URL.
my $browse_path = "$root_path/browse";

# JIRA rest api URL.
my $json_path = "$root_path/rest/api/latest";

# JIRA atom feed URL.
my $feed_path = "$root_path/activity";

# Bot can tell us where to find its source, not used for anything else.
my $bot_source_url = "https://gist.github.com/3977511";

# For !search command
my $max_search_results = 5;

# Minimum number of seconds between feed checks.
# Interval is increased by this amount when there is no activity.
my $tick_interval_min = 5;

# Maximum number of seconds between feed checks.
my $tick_interval_max = 300; 

my $tick_interval = $tick_interval_min;
my $feed_updated = ""; 
my $feed_last_desc = "";

# IRC admin user
my $admin = $ARGV[0];

#base64-encoded JIRA username:password
my $admin_auth = encode_base64($ARGV[1] . ':' . $ARGV[2]);

# All your base64 encoded JIRA logins are belong to us
my %auth = ( $admin => $admin_auth );

# Someone needs to be able to control the bot.
# !op <nick> to add more operators.
# !deop <nick> to remove operators.
my %operators = ($admin => 1);

# Report feed to these channels
my %channels = (); 

# Who is in the channels? Use this to anti-highlight.
# Keys are channel names, values are space-delimited lists of nicks. 
my %channel_nicks = (); 

# Who searched for what? 
my %nick_searches = (); 

# Set up our IRC "object environment."
my $irc = POE::Component::IRC->spawn();

# The bot session has started. Connect to a server.

sub on_start {
  
  print "Connecting...\n";
  
  $irc->yield(register => "all");
  
  $irc->yield(
    connect => {
      Nick     => 'moji`',
      Username => 'Moji',
      Ircname  => 'MojiBot',
      Server   => 'irc.esper.net',
      Port     => '6667',
    }
  );
}

# The bot has successfully connected to a server.

sub on_connect {
  
  print "Connected.\n";
  
}

# The bot has received a message.

sub on_msg {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick    = (split /!/, $who)[0];
  my $channel = $where->[0];
  my $ts      = scalar localtime;
  
  $channel = $nick if $channel eq $irc->nick_name();
  
  print " [$ts] <$nick:$channel> $msg\n";
  
  # Admin commands
  
  my $op_rank = $operators{$nick};
  
  if ($op_rank) {
  
    # op
  
    if ($msg =~ m/^!op\s*(.+)/) {
      
      return $irc->yield(notice => $nick, 
          "$1 is already an operator.") 
          if $operators{$1};
      
      $operators{$1} = $op_rank + 1;
    
      return $irc->yield(ctcp => $channel,
          "ACTION is now accepting operator commands from $1.");
      
    }
    
    # de-op
  
    if ($msg =~ m/^!deop\s*(.+)/) {
      
      return $irc->yield(notice => $nick,
          "$1 isn't an operator.") 
          if !$operators{$1};
      
      return $irc->yield(notice => $nick,
          "Operator rank for $1 equals or exceeds your own.") 
          if $operators{$1} <= $op_rank;
            
      delete $operators{$1};
      
      return $irc->yield(ctcp => $channel,
          "ACTION is no longer accepting operator commands from $1.");
      
    }
    
    # msg
  
    if ($msg =~ m/^!msg\s*([^\s]+)\s*(.*)/) {
      
      say_to($1, $2);
      return;
      
    }
    
    # ident(ify)
  
    if ($msg =~ m/^!ident(?:ify)?\s*(.+)/) {
      
      $irc->yield(nickserv => "IDENTIFY $1");
      return;
      
    }
    
    # single-arg eponymous commands
    # nick, join, part, mode
  
    if ($msg =~ m/^!(nick|join|part|mode)\s*(.+)/) {
      
      $irc->yield($1, $2);
      return;
      
    }
    
    # raw
  
    if ($msg =~ m/^!raw\s*(.+)/) {
      
      $irc->yield(quote => $1);
      return;
      
    }
  
  }
    
  # Log in. Format is username:password.
  
  if ($msg =~ m/^!(?:auth|login)\s*(.*)/) {
  
    $auth{$who} = encode_base64($1);
    say_to($channel, "Logged in.");
    return;
  
  }
  
  # Start echoing the feed in this channel
  
  if ($msg =~ m/^!feed\s*(.*)/) {
  
    if ($1 =~ m/^off$/) {
    
      delete $channels{$channel};
      
      return $irc->yield(ctcp => $channel,
          "ACTION stops reporting activity to $channel.");
    
    }
        
    $channels{$channel} = $1 ? $1 : '.';
      
    $tick_interval = $tick_interval_min;
  
    $_[KERNEL]->delay(bot_tick => 0);
    
    return $irc->yield(ctcp => $channel,
        "ACTION is now reporting " 
        . ($1 ? "activity matching '$1'" : 'all activity')
        . " to $channel.");
    
  }
  
  # Search for tickets using JQL
  
  if ($msg =~ m/^!search\s*(.+)/) {
    
    my $jql = $1;
    
    my $offset = 0;
    
    @{$nick_searches{$who}} = ( $jql, $offset );
    
    search($channel, $jql, $offset, $max_search_results);
    
    return;
    
  }
  
  # Search for a filter
  
  if ($msg =~ m/^!filter\s*(.+)/) {
    
    my $jql = 'filter="' . $1 .'"';
    
    my $offset = 0;
    
    @{$nick_searches{$who}} = ( $jql, $offset );
    
    search($channel, $jql, $offset, $max_search_results);
    
    return;
    
  }
  
  # Find (simple search)
  
  if ($msg =~ m/^!find\s*(.+)/) {
    
    my $query = $1;
    
    my $jql = '';
    
    my $offset = 0;
    
    if ($query =~ s/(^\s*(mc|mcpe|mcapi))\s+//i) {
      $jql .= "project=$1 & ";
    }
    
    $jql .= 'text~"' . $query . '"';
    
    @{$nick_searches{$who}} = ( $jql, $offset );
    
    search($channel, $jql, $offset, $max_search_results);
    
    return;
    
  }
  
  # Show the next page of search results

  if ($msg =~ m/^!more/) {
    
    return  if !$nick_searches{$who};
    
    $nick_searches{$who}[1] += $max_search_results;
    
    my ($jql, $offset) = @{$nick_searches{$who}};
    
    search($channel, $jql, $offset, $max_search_results);
    
    return;
    
  }
  
  # Show link to bot's source
  
  if ($msg =~ m/^!source/) {
    
    my $blue = chr(0x3) . 2;
    my $end = chr(0xf);
    
    say_to($channel, 
        "My source code is available at $blue$bot_source_url$end");
        
    return;
  }
  
  # Auto-link ticket keys
  
  while ($msg =~ m/((?:mc|mcpe|mcapi)-\d+)/ig) {

    my $json_url = "$json_path/issue/$1";
    
    eval { show_issue(fetch_json($json_url, $auth{$admin}), $channel); };
    
  }
  
}

# The bot ticks

sub on_tick {
    
  my $data = fetch_xml($feed_path, $auth{$admin});

  my $d = $data->{entry}->[0]->{updated};
  
  # Check if entry 0 has a new timestamp
  # TODO: HEAD request, check Last-Modified header
  
  if ($d && ($d ne $feed_updated)) {
  
    $feed_updated = $d;
      
    my $entry = $data->{entry}->[0];
    
    my $html_desc = $entry->{title}->{content};
    
    my $hs = HTML::Strip->new();
    
    my $desc = $hs->parse($html_desc); # strip html tags
   
    # collapse and strip whitespace
    $desc =~ s/\s+/ /g; 
    $desc =~ s/(?:^\s*)|(?:\s*$)//g;  
    
    # Make sure feed description has changed to avoid reporting 
    # redundant actions (like repeated edits to a description).
  
    if ($desc ne $feed_last_desc) {
    
      $feed_last_desc = $desc;
    
      my $dp = DateTime::Format::Strptime->new(
          pattern => '%Y-%m-%dT%H:%M:%S');
          
      my $updated = $dp->parse_datetime($d);
      
      my $link = $entry->{link}->[0]->{href};
      
      eval { $link = shorten_url($link); };
      
      my $msg = "$desc (" . ago($updated) . ") - $link";
      
      my @targets = ();
      
      while (my ($channel, $filter) = each %channels) {
  
        push @targets, $channel if $desc =~ m/$filter/i;
        
      }
      
      # my @targets = keys %channels;
      
      # print "$msg\n";
      
      say_to(join(',', @targets), $msg);
    
    }
    
    # Reset tick interval to the minimum
    
    $tick_interval = $tick_interval_min;
  
  } else {
  
    # Increase tick interval
  
    $tick_interval += $tick_interval_min;
    
    $tick_interval = $tick_interval_max 
        if $tick_interval > $tick_interval_max;
  
  }
   
  $_[KERNEL]->delay(bot_tick => $tick_interval) if %channels;
  
}

# We got a list of nicks in a channel (irc_353). 

sub on_names {

  my ($kernel, $server, $response) = @_[KERNEL, ARG0, ARG1];
  
  my ($channel, $names) = $response =~ m/(#[^\s]+)\s*:(.*)/;
  
  $names =~ s/[~&@%+]//g; #strip prefixes from names
  
  print "Got users for $server$channel: $names\n";
  
  $channel_nicks{$channel} = $names;
  
}


  
# Someone joined a channel that we're on. 
# ARG0 is the person's nick!hostmask. ARG1 is the channel name.
  
sub on_user_joined {

  my ($kernel, $who, $channel) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
   
  $channel_nicks{$channel} = "" if !$channel_nicks{$channel};
  
  $channel_nicks{$channel} .= 
      ($channel_nicks{$channel} ? ' ' : '') . $nick;
      
  print "$nick joined $channel -> " . $channel_nicks{$channel} . "\n";
  
}

# Someone left a channel that we're on. 
# ARG0 is the person's nick!hostmask. ARG1 is the channel name.
  
sub on_user_parted {

  my ($kernel, $who, $channel) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  $channel_nicks{$channel} = "" if !$channel_nicks{$channel};
  $channel_nicks{$channel} =~ s/\s*\b\Q$nick\E\b//g;
  $channel_nicks{$channel} =~ s/\s+$//g;
  
  print "$nick parted $channel -> " . $channel_nicks{$channel} . "\n";

}

# Someone changed their nick. 
# ARG0 is the person's nick!hostmask. ARG1 is the new nick.
  
sub on_user_nick {

  my ($kernel, $who, $new_nick) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  while (my ($channel, $nicks) = each %channel_nicks) {
  
    $channel_nicks{$channel} =~ s/\b\Q$nick\E\b/$new_nick/g;
    
    print "$nick renamed to $new_nick -> " . $channel_nicks{$channel} . "\n";
    
  }

}

# Do a JQL search and display results in channel.

sub search {

  my ($channel, $jql, $offset, $limit) = @_;
  
  my $json_url = "$json_path/search?jql=" . uri_escape($jql) 
      . "&startAt=$offset&maxResults=$limit";
    
  my $json = fetch_json($json_url, $auth{$admin}) or return;
  
  if ($json->{errorMessages}) {
    say_to($channel, @{$json->{errorMessages}}[0]);
    return;
  }
  
  my @issues = @{$json->{issues}} if $json->{issues} or return;

  my $total = $json->{total};
  
  my $first = $offset + 1;
  
  my $last = $offset + @issues;
  
  my $to = $last - $first == 1 ? 'and' : 'through';
  
  my $s = $total > 1 ? 's' : '';
        
  my $msg = !$total ? "No results" : 
      $total <= $limit ? "Showing $total result$s" :
      $last <= $first ? "Showing result $last of $total" :
      "Showing results $first $to $last of $total";
        
  my $bold = chr(0x2);
  my $end = chr(0xf);
  
  say_to($channel, "$bold$msg for $jql.$end");
  
  foreach my $issue (@issues) {
    
    show_issue($issue, $channel);
  
  }
      
}

# Show issue

sub show_issue {
    
  my ($issue, $channel) = @_;
  
  my $dp = DateTime::Format::Strptime->new(
      pattern => '%Y-%m-%dT%H:%M:%S.%N%z');

  my $updated = $dp->parse_datetime($issue->{fields}->{updated});
  
  my $comments = 0;
  
  my $url = "$browse_path/" . $issue->{key};
  
  eval { $comments = @{$issue->{fields}->{comment}->{comments}}; };
  
  eval { $url = shorten_url($url); };
  
  my $out = $issue->{key} . ": " 
      . $issue->{fields}->{summary} 
      . " - " . $issue->{fields}->{status}->{name} 
      . ", updated " . ago($updated);
      
  if ($comments) {
    my $s = $comments > 1 ? 's' : '';
    $out .= " ($comments comment$s)";
  }
  
  say_to($channel, "$out - $url");
  
}

# Send some text to a comma-delimited list of channels/users.

sub say_to {

  my ($channel, $text) = @_;
  
  $irc->yield(privmsg => $channel, anti_highlight($channel, $text));

}

# Search channels for IRC nicks that also occur in the message.
# Mangle message so it no longer contains the nicks.

sub anti_highlight {

  my ($channels, $text) = @_;
  
  my @channel_list = split ',', $channels;
  
  my $names = "";
  
  while (my $channel = shift @channel_list) {
    my $nicks = $channel_nicks{$channel};
    $names .= ($names ? ' ' : '') . $nicks if $nicks;
  }
  
  return $text if !$names;
  
  $names =~ s/\|/\\|/g; #escape pipes
  
  $names =~ s/(\s+)/\|/g; #delimit with pipes
  
  $text =~ s/\b($names)\b/@{[mangle($1)]}/gi;
  
  return $text;

}


sub mangle {

  my $text = shift;
  
  $text = Acme::Umlautify::umlautify($text);
  $text =~ s/n/ñ/g;
  $text =~ s/N/Ñ/g;

  return $text;

}

# How long ago was a DateTime?

sub ago {

  my $dur = DateTime->now() - shift;
  
  my $months = $dur->months();
  my $weeks = $dur->weeks();
  my $days = $dur->days();
  my $hours = $dur->hours();
  my $minutes = $dur->minutes();
  my $seconds = $dur->seconds();
  my $s;
  
  if ($months) {
    $s = $months > 1 ? 's' : '';
    return "$months month$s ago"
  }
  if ($weeks) {
    $s = $weeks > 1 ? 's' : '';
    return "$weeks week$s ago"
  }
  if ($days) {
    $s = $days > 1 ? 's' : '';
    return "$days day$s ago"
  }
  if ($hours) {
    $s = $hours > 1 ? 's' : '';
    return "$hours hour$s ago"
  }
  if ($minutes) {
    $s = $minutes > 1 ? 's' : '';
    return "$minutes minute$s ago"
  }
  if ($seconds) {
    $s = $seconds > 1 ? 's' : '';
    return "$seconds second$s ago"
  }

  return "just now";

}


# Shorten a URL using goo.gl
# https://developers.google.com/url-shortener/v1/getting_started
  
sub shorten_url {

  my $url = shift;
  
  my %request = ( longUrl => $url );
  
  my $data = encode_json(\%request);
  
  my $response = http(
    POST => 'https://www.googleapis.com/urlshortener/v1/url', 
    ( "Content-Type: application/json" ),
    $data
  );
  
  my $json = new JSON;
  
  eval {

    my $obj = $json->decode($response);
    
    $url = $obj->{id};
    
  };
  
  return $url;
    
}

# Fetch JSON from a URL

sub fetch_json {

  my ($url, $auth) = @_;
  my $json = new JSON; #TODO: make global?
  my $hash = {};
  my $response = !$auth ? http(GET => $url) : 
      http(GET => $url, ( "Authorization: Basic $auth" ));
      
  eval { $hash = $json->decode($response) };
  
  return $hash;
}

# Fetch XML from a URL

sub fetch_xml {

  my ($url, $auth) = @_;
  # setting KeyAttr prevents id elements from becoming keys of parent elements.
  my $xml = new XML::Simple(KeyAttr => 'xxxx'); #TODO: make global?
  my $hash = {};
  my $response = !$auth ? http(GET => $url) : 
      http(GET => $url, ( "Authorization: Basic $auth" ));
  
  eval { $hash = $xml->XMLin($response); };
  
  return $hash;
}

# Do http(s) stuff.
# Warning: fragile.

sub http {
  
  my ($action, $url, $headers, $body) = @_;
  
  my ($protocol, $domain) = $url =~ m#^(https?)://([^/]*)#i;
  
  my $socket = $protocol eq 'https' ? 
      new IO::Socket::SSL("$domain:https") :
      new IO::Socket::INET("$domain:http");

  return warn "Can't open socket to $domain over $protocol.\n" if !$socket;

  my $length = $body ? length $body : 0;
  
  my $br = "\r\n"; # nothing to see here...
  
  my $header_data = $headers ? $br . join $br, $headers : '';
  
  my $request = "$action $url HTTP/1.0$header_data$br"
      . ($length ? "Content-Length: $length$br$br$body" : $br);
  
  my $response;
    
  print $socket $request;
  
  # TODO: won't actually work with plain HTTP, needs a length arg
  $socket->read($response);  
  
  close $socket;
  
  $response =~ s/.*$br$br//ms; # strip the headers from the response
  
  return $response;

}

# Create and run the POE session.

POE::Session->create(
  inline_states => {
    _start      => \&on_start,
    irc_001     => \&on_connect,
    irc_353     => \&on_names,
    irc_join    => \&on_user_joined,
    irc_part    => \&on_user_parted,
    irc_nick    => \&on_user_nick,
    irc_public  => \&on_msg,
    irc_msg     => \&on_msg,
    bot_tick    => \&on_tick,
  },
);

$poe_kernel->run();

exit 0;
