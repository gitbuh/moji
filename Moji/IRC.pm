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

my $reconnect_timeout = 5;

my $has_traffic = 1;

# Things for plugins to populate

# POE states (IRC or other)
our $bot_states = {
  _start      => \&on_start,
  irc_001     => \&on_connect,
  irc_public  => \&on_msg,
  irc_msg     => \&on_msg,
  irc_notice     => \&on_msg,
  irc_disconnected => \&on_disconnect,
  irc_error =>        \&on_disconnect,
  irc_socketerr =>    \&on_disconnect,
  bot_mutter =>    \&mutter,
};

sub run {

  # Create and run the POE session.
  POE::Session->create(inline_states => $bot_states);
  $poe_kernel->run();

}


sub mutter {

  if ($has_traffic < 0) {
    $irc->disconnect();
  }

  $irc->yield(privmsg => $irc->nick_name(), "mumble, mumble")
      unless $has_traffic;
      
  --$has_traffic;
      
  $poe_kernel->delay(bot_mutter => 300);

}

# The bot session has started. Connect to a server.

sub on_start {
  print "Connecting...\n";
  $irc->yield(register => "all");
  $irc->yield(connect => ${Moji::Opt::bot_info});
  mutter();
}

# The bot has successfully connected to a server.

sub on_connect {
  
  print "Connected.\n";
  
  my $user = ${Moji::Opt::irc_user};
  my $pass = ${Moji::Opt::irc_pass};
  
  $irc->yield(nickserv => "identify $user $pass")
      if $pass;
  
  $irc->yield(join => "#botz");
  
}

# The bot has been disconnected.

sub on_disconnect {
  
  print "Disconnected, reconnecting in $reconnect_timeout seconds.\n";
  
  $poe_kernel->delay(_start => $reconnect_timeout);
  
}

# The bot has received a message.

sub on_msg {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick    = (split /!/, $who)[0];
  my $channel = $where->[0];
  my $ts      = scalar localtime;
  
  $has_traffic = 1;
  
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
