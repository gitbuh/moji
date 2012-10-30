#!/usr/bin/perl

# http://search.cpan.org/dist/POE-Component-IRC/lib/POE/Component/IRC.pm

use warnings;
use strict;

use DateTime::Format::Strptime;
use DateTime::Format::Duration;
use IO::Socket::SSL;
use IO::Socket::INET;
use URI::Escape;
use WWW::Mechanize;
use HTML::Strip;
use XML::Simple;
use JSON;
use POE;
use POE::Component::IRC;
use MIME::Base64;

# Someone needs to be able to control the bot.
# !op <nick> to add more operators.
# !deop <nick> to remove operators.

my $admin = 'Bop'; # JIRA moderator user

my $admin_auth = 'xxxxxxxxxxxxxxxx'; #base64-encoded JIRA username:password

my %operators = ($admin => 1);

# JIRA root URL.
my $root_path = "https://mojang.atlassian.net";

# JIRA browse URL.
my $browse_path = "$root_path/browse";

# JIRA rest api URL.
my $json_path = "$root_path/rest/api/latest";

# JIRA atom feed URL.
my $feed_path = "$root_path/activity";

# Minimum number of seconds between feed checks.
# Interval is increased by this amount when there is no activity.
my $tick_interval_min = 5;

# Maximum number of seconds between feed checks.
my $tick_interval_max = 300; 

my $tick_interval = $tick_interval_min;     
my $feed_updated = ""; 
my $feed_last_desc = "";
my $irc = POE::Component::IRC->spawn();

my %channels = (); # Report feed to these channels
my %auth = ( $admin => $admin_auth ); # All your base64 encoded JIRA logins are belong to us
my %channel_nicks = (); # Who is in the channels? Use this to anti-highlight.

# The bot session has started. Connect to a server.

sub on_start {
  
  print "Connecting...\n";
  
  $irc->yield(register => "all");
  
  $irc->yield(
    connect => {
      Nick     => 'moji',
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
  
  if ($channel eq $irc->nick_name()) {
    $channel = $nick;
  }
  
  print " [$ts] <$nick:$channel> $msg\n";
  
  # Admin commands
  
  my $op_rank = $operators{$nick};
  
  if ($op_rank) {
  
    # op
  
    if ($msg =~ m/^!op\s*(.+)/) {
	    
	    if ($operators{$1}) {
	      
        $irc->yield(notice => $nick => 
            "$1 is already an operator.");
            
        return;
        
	    }
	    
      $operators{$1} = $op_rank + 1;
    
      $irc->yield(ctcp => $channel => 
          "ACTION is now accepting operator commands from $1.");
	    
    }
    
    # de-op
  
    if ($msg =~ m/^!deop\s*(.+)/) {
	    
	    
	    if (!$operators{$1}) {
	    
        $irc->yield(notice => $nick => 
            "$1 isn't an operator.");
            
        return;
	    
	    }
	    
	    if ($operators{$1} <= $op_rank) {
	    
        $irc->yield(notice => $nick => 
            "Operator rank for $1 equals or exceeds your own.");
            
        return;
	    
	    }
	    
      delete $operators{$1};
      
      $irc->yield(ctcp => $channel => 
          "ACTION is no longer accepting operator commands from $1.");
          
      return;
	    
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
  
  }
  
  # Start echoing the feed in this channel
  
  if ($msg =~ m/^!(?:feed|activity)\s*(.*)/) {
  
    if ($1 =~ m/off/) {
    
      delete $channels{$channel};
      
      $irc->yield(ctcp => $channel => 
          "ACTION stops reporting activity to $channel.");
      
      return;
    
    } else {
  
      $irc->yield(ctcp => $channel => 
          "ACTION is now reporting activity to $channel.");
          
      $channels{$channel} = 1;
	      
      $tick_interval = $tick_interval_min;
    
      $_[KERNEL]->delay(bot_tick => 0);
      
      return;
      
    }
    
  }
  
  # Search for tickets using JQL
  
  if ($msg =~ m/^!(?:find|search)\s*(.+)/) {
    
    my $jql = uri_escape($1);
    
    my $json_url = "$json_path/search?jql=$jql&maxResults=5";
    
    eval {
    
      my $json = fetch_json($json_url, $auth{$admin});
      
      my @issues = @{$json->{issues}};
      
      if (@issues)  {
              
        my $msg = "Found " . $json->{total} . " results";
        
        if (@issues < $json->{total}) {
          
          $msg .= ", showing " . @issues; 
          
        }
              
        say_to($channel, "$msg.");
        
        foreach my $issue (@issues) {
          
          show_issue($issue, $channel);
        
        }
      
      }
      
    };
    
    return;
    
  }
  
  # Auto-link ticket keys
  
  while ($msg =~ m/((?:mc|mcpe|mcapi)-\d+)/ig) {

    my $json_url = "$json_path/issue/$1";
    
    eval {
    
      show_issue(fetch_json($json_url, $auth{$admin}), $channel);
	  
	  };
	  
  }
  
}

# The bot ticks

sub on_tick {
    
  my $data = fetch_xml($feed_path);

  my $d = $data->{entry}->[0]->{updated};
  
  # Check if entry 0 has a new timestamp
  # TODO: HEAD request, check Last-Modified header
  
  if ($d ne $feed_updated) {
  
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
    
      my $dp = DateTime::Format::Strptime->new(
          pattern => '%Y-%m-%dT%H:%M:%S');
          
      my $updated = $dp->parse_datetime($d);
      
      my $link = shorten_url($entry->{link}->[0]->{href});
      
      my $msg = "$desc (" . ago($updated) . ") - $link";
      
      my @targets = keys %channels;
      
      print $msg;
      
      say_to(join(',', @targets), $msg);
    
    }
    
    # Reset tick interval to the minimum
    
    $tick_interval = $tick_interval_min;
  
  } else {
  
    # Increase tick interval
  
    $tick_interval += $tick_interval_min;
    
    if ($tick_interval > $tick_interval_max) {
      
      $tick_interval = $tick_interval_max;
      
    }
  
  }
  
  if (%channels) {
    $_[KERNEL]->delay(bot_tick => $tick_interval);
  }
  
}

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
  
  if (!$channel_nicks{$channel}) {
    $channel_nicks{$channel} = "";
  };
  
  $channel_nicks{$channel} .= 
      ($channel_nicks{$channel} ? ' ' : '') . $nick;
      
  print "$nick joined $channel -> " . $channel_nicks{$channel} . "\n";
  
}

# Someone left a channel that we're on. 
# ARG0 is the person's nick!hostmask. ARG1 is the channel name.
  
sub on_user_parted {

  my ($kernel, $who, $channel) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  if (!$channel_nicks{$channel}) {
    $channel_nicks{$channel} = "";
  };
  
  $channel_nicks{$channel} =~ s/\s*$nick//g;
  $channel_nicks{$channel} =~ s/\s+$//g;
  
  print "$nick parted $channel -> " . $channel_nicks{$channel} . "\n";

}

# Someone changed their nick. 
# ARG0 is the person's nick!hostmask. ARG1 is the new nick.
  
sub on_user_nick {

  my ($kernel, $who, $new_nick) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  while (my ($channel, $nicks) = each %channel_nicks) {
  
    $channel_nicks{$channel} =~ s/$nick/$new_nick/g;
    
    print "$nick renamed to $new_nick -> " . $channel_nicks{$channel} . "\n";
    
  }

}

sub say_to {

  my ($channel, $text) = @_;
  
  $irc->yield(privmsg => $channel, anti_highlight($channel, $text));

}

sub anti_highlight {

  my ($channels, $text) = @_;
  
  my @channel_list = split ',', $channels;
  
  my $names = "";
  
  while (my $channel = shift @channel_list) {
    my $nicks = $channel_nicks{$channel};
    if ($nicks) {
      $names .= ($names ? ' ' : '') . $nicks;
    }
  }
  
  if (!$names) {
  
    return $text;
  
  }
  
  my $shy = chr(0x00ad); #soft hyphen.

  $names =~ s/\|/\\|/g; #escape pipes
  
  $names =~ s/(\s+)/\|/g; #delimit with pipes
  
  $text =~ s/\b($names)\b/@{[(substr $1, 0, 1) . $shy . (substr $1, 1)]}/g;
  
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


# Show issue

sub show_issue {

  my $issue = shift();
  my $channel = shift();
  
  my $dp = DateTime::Format::Strptime->new(
      pattern => '%Y-%m-%dT%H:%M:%S.%N%z');

  my $updated = $dp->parse_datetime($issue->{fields}->{updated});
  
  my $comments = 0;
  
  my $url = "$browse_path/" . $issue->{key};
  
  eval {
    $comments = @{$issue->{fields}->{comment}->{comments}};
  };
  
  eval {
    $url = shorten_url($url);
  };
  
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

# Shorten a URL using goo.gl
# https://developers.google.com/url-shortener/v1/getting_started#shorten
  
sub shorten_url {

  my $url = shift;
  
  my $client = new IO::Socket::SSL("www.googleapis.com:https");
  
  my %request = ( longUrl => $url );
  
  my $data = encode_json(\%request);
  
  my $response = http( "POST", 'https://www.googleapis.com/urlshortener/v1/url', 
    ( "Content-Type: application/json" ),
    $data
  );
  
  my $json = new JSON;

  my $obj = $json->decode($response);
  
  return $obj->{id};
    
}


# Fetch JSON from a URL

sub fetch_json {

  my ($url, $auth) = @_;
  my $json = new JSON; #TODO: make global?
  my $response = !$auth ? http('GET', $url) : 
      http('GET', $url, ( "Authorization: Basic $auth)" ));
  return $json->decode($response);
}

# Fetch XML from a URL

sub fetch_xml {

  my $xml_url = shift;
  my $xml = new XML::Simple(KeyAttr => 'xxxx'); #TODO: make global?
  # setting KeyAttr to prevent id elements from becoming keys of parent elements 
    
  return $xml->XMLin(http('GET', $xml_url));

}

# Do http(s) stuff.
# Warning: fragile.
sub http {
  
  my ($action, $url, $headers, $body) = @_;
  
  my ($protocol, $domain) = $url =~ m#^(https?)://([^/]*)#i;
  
  my $socket = $protocol eq 'https' ? 
      new IO::Socket::SSL("$domain:https") :
      new IO::Socket::INET("$domain:http");

  if (!$socket) { 
    warn "Can't open socket to $domain over $protocol.\n";
    return; 
  }

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
  
  $response =~ s/.*\r\n\r\n//ms; # strip the headers from the response
  
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