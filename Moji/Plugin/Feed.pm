package Moji::Plugin::Feed;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use HTML::Strip;
use Moji::IRC;
use Moji::Net;
use Moji::Opt;
use POE;

# Report feed to these channels
our $channels = {}; 

# Date/time string from the last feed massage
our $feed_last_id = "";

# Current number of seconds between feed checks.
our $tick_interval = ${Moji::Opt::tick_interval_min};


sub setup { 

  return {

    commands => {
    
      feed => \&feed, # Start echoing the feed in this channel
    
    },

    states => {
      
      feed_tick    => \&on_feed_tick,
    
    },
    
  };

}

sub feed {

  my ($args, $nick, $channel) = @_;

  if ($args =~ m/^off$/) {
  
    delete $channels->{$channel};
    
    return $irc->yield(ctcp => $channel,
        "ACTION stops reporting activity to $channel.");
  
  }
      
  $channels->{$channel} = $args ? $args : '.';
    
  $tick_interval = ${Moji::Opt::tick_interval_min};

  $poe_kernel->delay(feed_tick => 0);
  
  return $irc->yield(ctcp => $channel,
      "ACTION is now reporting " 
      . ($args ? "activity matching '$args'" : 'all activity')
      . " to $channel.");

}


sub on_feed_tick {
    
  return if !$channels;
    
  my $data = get_xml(
      ${Moji::Opt::feed_path}, ${Moji::Opt::jira_credentials});
  
  # TODO: HEAD request, check Last-Modified header
  
  # Display new feed activity...
    
  # Count how many entries we skipped
  my $skipped = 0;
  
  for my $entry (@{$data->{entry}}) {

    last if $entry->{id} eq $feed_last_id;
    ++$skipped;
    
  }
  
  # Only show 1 entry if we just started the bot.
  $skipped = 1 if !$feed_last_id;
  
  # If no activity, increase tick interval and return.
  if (!$skipped) {
  
    $tick_interval += ${Moji::Opt::tick_interval_min};
    
    $tick_interval = ${Moji::Opt::tick_interval_max} 
        if $tick_interval > ${Moji::Opt::tick_interval_max};
        
    return $poe_kernel->delay(feed_tick => $tick_interval);
  
  }
  
  #TODO: make these global?
  
  my $hs = HTML::Strip->new();  
  
  $feed_last_id = $data->{entry}->[0]->{id};
  
  # Show skipped entries to subscribed channels.
  while (--$skipped >= 0) {
      
    my $entry = $data->{entry}->[$skipped];
    
    my $html_desc = $entry->{title}->{content};
    
    my $desc = $hs->parse($html_desc); # strip html tags
   
    # collapse and strip whitespace
    $desc =~ s/\s+/ /g; 
    $desc =~ s/(?:^\s*)|(?:\s*$)//g;  
    
    my $updated = Moji::Time::parse($entry->{updated});
    
    my $link = Moji::Net::shorten_url($entry->{link}->[0]->{href});
    
    my @targets = ();
    
    my $msg = "$desc (" . Moji::Time::ago($updated) . ") - $link";
    
    while (my ($channel, $filter) = each %$channels) {

      push @targets, $channel if $desc =~ m/$filter/i;
      
    }
    
    say_to((join ',', @targets), $msg);
    
  }
  
  $tick_interval = ${Moji::Opt::tick_interval_min};
   
  $poe_kernel->delay(feed_tick => $tick_interval);
  
}
1;
