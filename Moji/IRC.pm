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

our $irc = POE::Component::IRC->spawn();

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
  
  # Run commands and responders
  
  return if Moji::Plugin::run_commands($msg, $nick, $channel);
  return if Moji::Plugin::run_responders($msg, $nick, $channel);
  
}

# Send some text to a comma-delimited list of channels/users.

sub say_to {
  my ($who, $message) = @_;
  $message = Moji::Plugin::run_transformers($who, $message);
  $irc->yield(privmsg => ($who, $message));
}

1;
