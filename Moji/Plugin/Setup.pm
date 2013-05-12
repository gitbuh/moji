package Moji::Plugin::Setup;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use Moji::IRC;
use Moji::Jira;
use Moji::Net;
use Moji::Opt;
use Moji::Plugin::Feed;

sub setup { 

  return {

    responders => {
    
      R1501 => sub {
    
        my ($msg, $nick, $channel, $kernel) = @_;

        if ($nick eq $channel and $nick =~ m/^nickserv$/i) {
        
          if ($msg =~ m/You are now identified/) {
          
             $irc->yield(join => '#mojira,#mojira-lounge,#mojira-staff,#mojira-mcpe');
            
            Moji::Plugin::Feed::feed('', 'nobody', '#mojira');
            Moji::Plugin::Feed::feed('spam golem', 'nobody', '#mojira-staff');
            Moji::Plugin::Feed::feed('mcpe', 'nobody', '#mojira-mcpe');
            
          
          }
        
          return 1;
        
        }
        
      },
    
    },
    
  };

}

1;
