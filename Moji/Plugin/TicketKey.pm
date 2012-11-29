package Moji::Plugin::TicketKey;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use Moji::IRC;
use Moji::Jira;
use Moji::Net;
use Moji::Opt;

sub setup { 

  return {

    responders => {
    
      R1001 => sub {
    
        my ($msg, $nick, $channel, $kernel) = @_;
        
        my $responded = 0;

        while ($msg =~ m/((?:mc|mcpe|mcapi)-\d+)/ig) {
          
          my $issue = get_issue($1);
          
          eval { 
          
            say_to($channel, format_issue($issue));

            $responded = 1;
          
          };
         
        }
        
        return $responded;
        
      },
    
    },
    
  };

}

1;
