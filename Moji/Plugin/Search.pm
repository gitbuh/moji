package Moji::Plugin::Search;

use strict;
use warnings;

use Moji::Plugin;
our @ISA = qw/ Moji::Plugin /;

use Moji::IRC;
use Moji::Jira;
use Moji::Net;
use Moji::Opt;
use POE;

# Who searched for what? 
# our $nick_searches = {}; 
our $channel_searches = {}; 

sub setup { 

  return {

    commands => {
      
      # Search for tickets using JQL

      search => sub {
        my ($jql, $nick, $channel) = @_;
        
        my $offset = 0;
        
        # @{$nick_searches->{$nick}} = ( $jql, $offset );
        @{$channel_searches->{$channel}} = ( $jql, $offset );
        
        search($channel, $jql, $offset, ${Moji::Opt::max_search_results});

      },

      # Search for a filter

      filter => sub {
        my ($args, $nick, $channel) = @_;
        
        my $jql = 'filter="' . $args .'"';
        
        my $offset = 0;
        
        # @{$nick_searches->{$nick}} = ( $jql, $offset );
        @{$channel_searches->{$channel}} = ( $jql, $offset );
        
        search($channel, $jql, $offset, ${Moji::Opt::max_search_results});

      },

      # Find (simple search)

      find => sub {
        my ($query, $nick, $channel) = @_;
        
        my $jql = '';
        
        my $offset = 0;
        
        if ($query =~ s/(^\s*(mc|mcpe|mcapi))\s+//i) {
          $jql .= "project=$1 & ";
        }
        
        $jql .= 'text~"' . $query . '"';
        
        # @{$nick_searches->{$nick}} = ( $jql, $offset );
        @{$channel_searches->{$channel}} = ( $jql, $offset );
        
        search($channel, $jql, $offset, ${Moji::Opt::max_search_results});
        
        return;

      },

      # Show the next page of search results

      more => sub {
      
        my ($args, $nick, $channel) = @_;
          
        # return if !$nick_searches->{$nick};
        
        return if !$channel_searches->{$channel};
        
        # $nick_searches->{$nick}[1] += ${Moji::Opt::max_search_results};
        
        $channel_searches->{$channel}[1] += ${Moji::Opt::max_search_results};
        
        # my ($jql, $offset) = @{$nick_searches->{$nick}};
        
        my ($jql, $offset) = @{$channel_searches->{$channel}};
        
        search($channel, $jql, $offset, ${Moji::Opt::max_search_results});
        
        return;
        
      }

    },

  };

}

# Do a JQL search and display results in channel.

sub search {
  my ($channel, $jql, $offset, $limit) = @_;
  
  my $result = search_issues($jql, $offset, $limit);
  
  if ($result->{errorMessages}) {
    say_to($channel, @{$result->{errorMessages}}[0]);
    return;
  }
  
  my @issues = @{$result->{issues}} if $result->{issues} or return;
  
  say_to($channel, $result->{moji_title});
  
  foreach my $issue (@issues) {
    
    show_issue($issue, $channel);
  
  }
      
}

# Show issue

sub show_issue {
  my ($issue, $channel) = @_;
  say_to($channel, format_issue($issue));
}


1;
