package Moji::Plugin::Op;

use strict;
use warnings;

use Moji::Plugin;
our @ISA         = qw/ Moji::Plugin /;

use Moji::IRC;
use Moji::Net;
use Moji::Opt;
use POE;

# Someone needs to be able to control the bot.
# !op <nick> to add more operators.
# !deop <nick> to remove operators.
our $operators;

sub setup { 

  return {

    commands => {
    
      op => sub {
        my ($op, $nick, $channel) = @_;
        return if !$operators->{$nick};
        
        return $irc->yield(notice => $nick, 
            "$op is already an operator.") 
            if $operators->{$op};
        
        $operators->{$op} = $operators->{$nick} + 1;
      
        return $irc->yield(ctcp => $channel,
            "ACTION is now accepting operator commands from $op.");
      
      },
      
      deop => sub {
        my ($op, $nick, $channel) = @_;
        return if !$operators->{$nick};
        
        return $irc->yield(notice => $nick,
            "$1 isn't an operator.") 
            if !$operators->{$op};
        
        return $irc->yield(notice => $nick,
            "Operator rank for $op equals or exceeds your own.") 
            if $operators->{$op} <= $operators->{$nick};
              
        delete $operators->{$op};
        
        return $irc->yield(ctcp => $channel,
            "ACTION is no longer accepting operator commands from $op.");
        
      },
      
      msg => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        if ($args =~ m/^([^\s]+)\s*(.*)/) {
          say_to($irc, $1, $2);
          return;
        }
      },
      
      ident => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(nickserv => "IDENTIFY $args");
        return;
      },
      
      nick => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(nick => $args);
      },
      
      join => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(join => $args);
      },
      
      part => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(part => $args);
      },
      
      mode => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(mode => $args);
      },
      
      raw => sub {
        my ($args, $nick, $channel) = @_;
        return if !$operators->{$nick};
        $irc->yield(quote => $args);
      },
    
    },
     
  };
}

sub on_enable {
  $operators = {${Moji::Opt::op_nick} => 1};
}


1;
