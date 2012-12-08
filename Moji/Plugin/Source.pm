package Moji::Plugin::Source;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use Moji::Opt;
use Moji::IRC;

# Who searched for what? 
our $nick_searches = {}; 

sub setup { 

  return {

    commands => {

      # Show link to bot's source

      source => sub {
        my ($args, $nick, $channel) = @_;
          
        my $url = ${Moji::Opt::bot_source_url};
        my $blue = chr(0x3) . 2;
        my $end = chr(0xf);
        
        say_to($channel, "My source code is available at $blue$url$end");

      },

    },

  };

}

