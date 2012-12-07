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

  # get available projects

  my @projects = ();
  
  my $url = "${Moji::Opt::json_path}/project";
  
  my $a = get_json($url, ${Moji::Opt::jira_credentials});
  
  for my $obj (@{$a}) {

    push @projects, $obj->{key};
    
  }
  
  my $project_names = join '|', @projects;
  
  print "using projects: $project_names\n";  

  return {

    responders => {
    
      R1001 => sub {
    
        my ($msg, $nick, $channel, $kernel) = @_;
        
        my $responded = 0;

        while ($msg =~ m/((?:$project_names)-\d+)/ig) {
          
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
