package Moji::IRC;

use strict;
use warnings;

require Exporter;
our @ISA         = qw/ Exporter /;
our @EXPORT   = qw/ $irc $bot_states say_to /;

use Moji::Jira;
use Moji::Net;
use Moji::Opt;

use POE;
use POE::Component::IRC;
use Acme::Umlautify;

our $irc = POE::Component::IRC->spawn();

use Data::Dumper;

# Things for plugins to populate

# POE states (IRC or other)
our $bot_states = {
  _start      => \&on_start,
  irc_001     => \&on_connect,
  irc_public  => \&on_msg,
  irc_msg     => \&on_msg,
};

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
  
  # Look for matching commands
  
  my $commands = Moji::Plugin::get_all('commands');
  
  my $cmdlist = join '|', keys %$commands; 
  
  if ($cmdlist && $msg =~ m/\!($cmdlist)\s*(.*)/ig) {
  
    return $commands->{$1}($2, $nick, $channel, $kernel);
    
  }
  
  # Run autoresponders
  
  my $responders = Moji::Plugin::get_all('responders');
  
  for my $fn (sort keys %$responders) {
    return if $responders->{$fn}($msg, $nick, $channel, $kernel);
  }
  
}

# Send some text to a comma-delimited list of channels/users.

sub say_to {

  my ($who, $message) = @_;
  
  my $transformers = Moji::Plugin::get_all('transformers');
  
  for my $fn (sort keys %$transformers) {
    $message = $transformers->{$fn}($who, $message);
  }
  
  $irc->yield(privmsg => ($who, $message));

}

1;
