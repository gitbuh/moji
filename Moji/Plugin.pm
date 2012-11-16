package Moji::Plugin;

use strict;
use warnings;

use Moji::IRC;
use Moji::Opt;
use POE;

# use Data::Dumper;

sub enable {
  my $class = shift;
  
  my $plugin = bless { }, $class;
  my $commands = $plugin->get_commands();
  my $states = $plugin->get_states();
  
  print "enabling $class\n";
  
  while (my ($cmd, $fn) = each %$commands) {
   
    print "[c] $cmd\n";
  
    $bot_commands->{$cmd} = $fn;
    
  }
  
  while (my ($state, $fn) = each %$states) {
    
    print "[s] $state\n";
   
    $bot_states->{$state} = $fn;
    
  }
 
}

sub disable {

  my $module = shift;
  
  print "disabling $module\n";
  
  while (my ($cmd, $fn) = each %$module::commands) {
   
    print "... $cmd\n";
  
    delete $bot_commands->{$cmd};
    
  }
  
  while (my ($state, $fn) = each %$module::states) {
   
    print "... $state\n";
    
    delete $bot_states->{$state};
    
  }
  
}

sub get_commands { return { }; }
sub get_states { return { }; }


1;
