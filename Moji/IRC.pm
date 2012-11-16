package Moji::IRC;

use strict;
use warnings;

require Exporter;
our @ISA         = qw/ Exporter /;
our @EXPORT   = qw/ $irc $bot_commands $bot_states say_to /;


use Moji::Jira;
use Moji::Net;
use Moji::Opt;

use POE;
use POE::Component::IRC;
use Acme::Umlautify;

our $irc = POE::Component::IRC->spawn();

our $bot_states = {
  _start      => \&on_start,
  irc_001     => \&on_connect,
  irc_353     => \&on_names,
  irc_join    => \&on_user_joined,
  irc_part    => \&on_user_parted,
  irc_nick    => \&on_user_nick,
  irc_public  => \&on_msg,
  irc_msg     => \&on_msg,
};

# Who is in the channels? Use this to anti-highlight.
# Keys are channel names, values are space-delimited lists of nicks. 
our $channel_nicks = {}; 

# All available commands.
our $bot_commands = {}; 

sub run {

  # Create and run the POE session.
  POE::Session->create(inline_states => $bot_states);
  $poe_kernel->run();

}

# The bot session has started. Connect to a server.

sub on_start {
  print "Connecting...\n";
  $irc->yield(register => "all");
  $irc->yield(connect => ${Moji::Opt::bot_info});
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
  
  my $cmdlist = join '|', keys %$bot_commands; 
  
  my $re = "($cmdlist)";
  
  # Look for matching commands
  
  if ($msg =~ m/\!($cmdlist)\s*(.*)/ig) {
  
    print "lst: $cmdlist\ncmd: $1\nargs: $2\n";
  
    # Run the command
    return $bot_commands->{$1}($2, $nick, $channel, $kernel);
    
  }
  
  # Auto-link ticket keys
  #TODO: move this to a plugin
  
  while ($msg =~ m/((?:mc|mcpe|mcapi)-\d+)/ig) {

    my $url = "${Moji::Opt::json_path}/issue/$1";
    
    my $issue = get_json($url, ${Moji::Opt::jira_credentials});
    
    say_to($channel, format_issue($issue));
   
  }
  
}

# We got a list of nicks in a channel (irc_353). 

sub on_names {

  my ($kernel, $server, $response) = @_[KERNEL, ARG0, ARG1];
  my ($channel, $nicks) = $response =~ m/(#[^\s]+)\s*:(.*)/;
  
  $nicks =~ s/[~&@%+]//g; #strip prefixes from names
  set_nicks($nicks, $channel);
  
}

# Someone joined a channel that we're on. 
# ARG0 is the person's nick!hostmask. ARG1 is the channel name.
  
sub on_user_joined {

  my ($kernel, $who, $channel) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  add_nick($nick, $channel);
  
}

# Someone left a channel that we're on. 
# ARG0 is the person's nick!hostmask. ARG1 is the channel name.
  
sub on_user_parted {

  my ($kernel, $who, $channel) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  remove_nick($nick, $channel);

}

# Someone changed their nick. 
# ARG0 is the person's nick!hostmask. ARG1 is the new nick.
  
sub on_user_nick {

  my ($kernel, $who, $new_nick) = @_[KERNEL, ARG0, ARG1];
  my $nick = (split /!/, $who)[0];
  
  change_nick($nick, $new_nick);

}

sub set_nicks {

  my ($nicks, $channel) = @_;
  
  print "Got users for $channel: $nicks\n";
  
  $channel_nicks->{$channel} = $nicks;

}

sub add_nick {

  my ($nick, $channel) = @_;
   
  $channel_nicks->{$channel} = "" if !$channel_nicks->{$channel};
  
  $channel_nicks->{$channel} .= 
      ($channel_nicks->{$channel} ? ' ' : '') . $nick;
      
  print "$nick joined $channel -> " . $channel_nicks->{$channel} . "\n";

}

sub remove_nick {

  my ($nick, $channel) = @_;
  
  $channel_nicks->{$channel} = "" if !$channel_nicks->{$channel};
  $channel_nicks->{$channel} =~ s/\s*\b\Q$nick\E\b//g;
  $channel_nicks->{$channel} =~ s/\s+$//;
  
  print "$nick parted $channel -> " . $channel_nicks->{$channel} . "\n";

}

sub change_nick {

  my ($nick, $new_nick) = @_;
  
  while (my ($channel, $nicks) = each %$channel_nicks) {
  
    $channel_nicks->{$channel} =~ s/\b\Q$nick\E\b/$new_nick/g;
    
    print "$nick renamed to $new_nick -> " . $channel_nicks->{$channel} . "\n";
    
  }

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
    my $nicks = $channel_nicks->{$channel};
    $names .= ($names ? ' ' : '') . $nicks if $nicks;
  }
  
  return $text if !$names;
  
  $names =~ s/\|/\\|/g; #escape pipes
  
  $names =~ s/(\s+)/\|/g; #delimit with pipes
  
  $text =~ s/\b($names)\b/@{[mangle($1)]}/gi;
  
  return $text;

}

# Dots and squiggles

sub mangle {

  my $text = shift;
  
  $text = Acme::Umlautify::umlautify($text);
  $text =~ s/n/ñ/g;
  $text =~ s/N/Ñ/g;

  return $text;

}

1;
