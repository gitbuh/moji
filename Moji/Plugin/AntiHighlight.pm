package Moji::Plugin::AntiHighlight;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use Acme::Umlautify;
use Moji::IRC;
use Moji::Net;
use Moji::Opt;
use POE;

# Who is in the channels? Use this to anti-highlight.
# Keys are channel names, values are space-delimited lists of nicks. 
our $channel_nicks = {}; 

sub setup { 

  return {

    states => {
    
      irc_353     => \&on_names,
      irc_join    => \&on_user_joined,
      irc_part    => \&on_user_parted,
      irc_nick    => \&on_user_nick,
    
    },
    
    transformers => { 
    
      T1001 => \&anti_highlight 
      
    },

  };
  
}

# We got a list of nicks in a channel (irc_353). 

sub on_names {

  my ($kernel, $server, $response) = @_[KERNEL, ARG0, ARG1];
  my ($channel, $nicks) = $response =~ m/(#[^\s]+)\s*:(.*)/
      or return;
  
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
  
  remove_nick($nick, $channel, 1);
   
  $channel_nicks->{$channel} = "" if !$channel_nicks->{$channel};
  
  $channel_nicks->{$channel} .= 
      ($channel_nicks->{$channel} ? ' ' : '') . $nick;
      
  print "$nick joined $channel -> " . $channel_nicks->{$channel} . "\n";

}

sub remove_nick {

  my ($nick, $channel, $hush) = @_;
  
  $channel_nicks->{$channel} = "" if !$channel_nicks->{$channel};
  $channel_nicks->{$channel} =~ s/\s*\b\Q$nick\E\b//g;
  $channel_nicks->{$channel} =~ s/\s+$//;
  
  print "$nick parted $channel -> " . $channel_nicks->{$channel} . "\n"
      if !$hush;

}

sub change_nick {

  my ($nick, $new_nick) = @_;
  
  while (my ($channel, $nicks) = each %$channel_nicks) {
  
    $channel_nicks->{$channel} =~ s/\b\Q$nick\E\b/$new_nick/g;
    
    print "$nick renamed to $new_nick -> " . $channel_nicks->{$channel} . "\n";
    
  }

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
  
  my $n = chr 241;
  my $N = chr 209;
  
  $text =~ s/n/$n/g;
  $text =~ s/N/$N/g;

  return $text;

}


1;
