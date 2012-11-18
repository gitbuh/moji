package Moji::Plugin;

use strict;
use warnings;

use Moji::IRC;

# use Data::Dumper;

our $plugins = { };
our @plugin_names = ( );

# Static methods

sub load {

  my @names = @_;

  for my $name (@names) {
  
    if (!$plugins->{$name}) {
  
      my $module = "Moji::Plugin::$name";
      require "Moji/Plugin/$name.pm";
      $module->import();
      $plugins->{$name} = (bless { name => $name }, $module);
      push @plugin_names, $name;
    
    }
    
  }
  
  return $plugins;
  
}

sub setup_all {
  for my $name (@plugin_names) { $plugins->{$name}->setup(); }
}

sub teardown_all {
  for my $name (@plugin_names) { $plugins->{$name}->teardown(); }
}

sub enable_all {
  for my $name (@plugin_names) { $plugins->{$name}->enable(); }
}

sub disable_all {
  for my $name (@plugin_names) { $plugins->{$name}->disable(); }
}


sub get_all { 

  my $what = shift;
  
  my $get_things = "get_$what";

  my %all = ( );
  
  while (my ($name, $plugin) = each %$plugins) {
  
    next if !($plugin->{enabled} && $plugin->$get_things);
  
    my $things = $plugin->$get_things();
    
    my %everything = (%all, %$things);
    
    %all = %everything;
  
  }

  return \%all;
  
}

# Instance methods, override these as needed

sub on_setup { };
sub on_teardown { };
sub on_enable { };
sub on_disable { };

sub get_commands { return { }; }
sub get_states { return { }; }
sub get_responders { return { }; }
sub get_transformers { return { }; }

# Instance methods

sub setup { 

  my $self = shift;
  
  $self->on_setup(); 
  
}

sub teardown { 

  my $self = shift;
  
  $self->on_teardown(); 
  
}

sub enable {

  my $self = shift;

  return if $self->{enabled};
  
  $self->{enabled} = 1;

  my $states = $self->get_states();
  
  while (my ($state, $fn) = each %$states) {
    
    $bot_states->{$state} = $fn;
    
  }
  
  $self->on_enable(); 
 
 
}

sub disable {

  my $self = shift;

  return if !$self->{enabled};
  
  $self->{enabled} = 0;
  
  my $states = $self->get_states();
  
  while (my ($state, $fn) = each %$states) {
    
    delete $bot_states->{$state};
    
  }
  
  $self->on_disable(); 

}

1;
