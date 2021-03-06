package Moji::Plugin;

use strict;
use warnings;

use Moji::IRC;

use Data::Dumper;

our $plugins = { };
our @plugin_names = ( );

# Static methods

sub load {

  my @names = @_;

  for my $name (@names) {
  
    next if $plugins->{$name};
  
    my $module = "Moji::Plugin::$name";
    
    print "Loading $module\n";
      
    require "Moji/Plugin/$name.pm";
    $module->import();
    my $plugin = $module->setup();
    
    $plugin->{name} = $name;
    $plugins->{$name} = bless $plugin, $module;
    push @plugin_names, $name;
    
    print Dumper($plugin);
    
  }
  
  return $plugins;
  
}

sub load_all {

  opendir (PLUGINS, 'Moji/Plugin') or die $!;
  
  while (my $plugin = readdir(PLUGINS)) {

    if ($plugin =~ s/(.+)\.pm$/$1/) {
    
      load($plugin);
    
    }
    
  }
  
  closedir(PLUGINS);
 
}

sub enable_all {
  for my $name (@plugin_names) { $plugins->{$name}->enable(); }
}

sub disable_all {
  for my $name (@plugin_names) { $plugins->{$name}->disable(); }
}

sub destroy_all {
  for my $name (@plugin_names) { $plugins->{$name}->destroy(); }
}


sub run_all {

  return _run(
    fn => shift, 
    return_many => wantarray, 
    args => @_
  );

}

sub run_some {

  return _run(
    fn => shift, 
    return_many => wantarray, 
    return_early => 1, 
    args => @_
  );

}

sub _run {

  my %args = @_;
  my $fn = $args{fn} or return;
  my $last_result = $args{args}[0];
  my @results = ( );

  while (my ($name, $plugin) = each %$plugins) {
    
    next if !($plugin->{$fn} && $plugin->{enabled}); 
  
    $last_result = $plugin->{$fn}($last_result, $args{args});
    
    push @results, $last_result if $args{return_many};
    
    return $last_result if $args{return_early} && $last_result;
  
  }
  
  return $args{return_many} ? @results : $last_result;

}


sub get_all { return get_some(shift); }

sub get_enabled { return get_some(shift, 1); }

sub get_some { 

  my ($member, $enabled_only) = @_;

  my %all = ( );
  
  while (my ($name, $plugin) = each %$plugins) {
    
    next if !$plugin->{$member}; 
    
    next if $enabled_only && !$plugin->{enabled}; 
  
    %all = (%all, %{$plugin->{$member}});
  
  }

  return \%all;
  
}

sub run_commands {
  my $commands = get_enabled('commands');
  my $cmdlist = join '|', keys %$commands;  
  
  if ($cmdlist && shift =~ m/^\!($cmdlist)\s*(.*)/ig) {
    return $commands->{$1}($2, @_) || 1;
  }
}

sub run_responders {
  my $responders = get_enabled('responders');
  
  for my $fn (sort keys %$responders) {
    return 1 if $responders->{$fn}(@_);
  }
}

sub run_states {
  my $state = shift;
  while (my ($name, $plugin) = each %$plugins) {
    $plugin->{states}->{$state}(@_) 
        if $plugin->{states} 
        && $plugin->{states}->{$state} 
        && $plugin->{enabled};
  }
}

sub run_transformers {
  my ($who, $message) = @_;
  my $transformers = get_enabled('transformers');
  for my $fn (sort keys %$transformers) {
    $message = $transformers->{$fn}($who, $message);
  }
  return $message;
}

# Instance methods, override these as needed

sub on_enable { };
sub on_disable { };
sub setup { return { }; }
sub destroy { }

# Instance methods

sub enable {

  my $self = shift;

  return if $self->{enabled};
  
  $self->{enabled} = 1;
  
  while (my ($state, $fn) = each %{$self->{states}}) {
    
    next if $bot_states->{$state};
    
    $bot_states->{$state} = sub {
    
      run_states($state, @_);
    
    }
    
  }
  
  $self->on_enable(); 
 
}

sub disable {

  my $self = shift;

  return if !$self->{enabled};
  
  $self->{enabled} = 0;
  
  $self->on_disable(); 

}

1;
