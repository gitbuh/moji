package Moji::Jira;

use strict;
use warnings;

require Exporter;
our @ISA         = qw/ Exporter /;
our @EXPORT   = qw/ search_issues get_issue format_issue /;

use Moji::Net;
use Moji::Time;

use URI::Escape;

# Do a JQL search and return results.

sub search_issues {

  my ($jql, $offset, $limit) = @_;
  
  my $json_url = "${Moji::Opt::json_path}/search?jql=" 
      . uri_escape($jql) . "&startAt=$offset&maxResults=$limit";
    
  my $result = get_json(
      $json_url, ${Moji::Opt::jira_credentials}) or return;
  
  return $result if $result->{errorMessages};
  
  my @issues = @{$result->{issues}} if $result->{issues} or return $result;

  my $total = $result->{total};
  
  my $first = $offset + 1;
  
  my $last = $offset + @issues;
  
  my $to = $last - $first == 1 ? 'and' : 'through';
  
  my $s = $total > 1 ? 's' : '';
        
  my $msg = !$total ? "No results" : 
      $total <= $limit ? "Showing $total result$s" :
      $last <= $first ? "Showing result $last of $total" :
      "Showing results $first $to $last of $total";
        
  my $bold = chr(0x2);
  
  my $end = chr(0xf);
  
  $result->{moji_title} = "$bold$msg for $jql.$end";
  
  return $result;
      
}

# get issue

sub get_issue {

  my $key = shift;

  my $url = "${Moji::Opt::json_path}/issue/$key";
  
  return get_json($url, ${Moji::Opt::jira_credentials});
  
}

# format issue

sub format_issue {
    
  my ($issue, $channel) = @_;
  
  my $updated = Moji::Time::parse($issue->{fields}->{updated});
  
  my $url = Moji::Net::shorten_url(
      "${Moji::Opt::browse_path}/" . $issue->{key});
  
  my $comments;
  
  my $out = $issue->{key} . ": " 
      . $issue->{fields}->{summary} 
      . " - " . $issue->{fields}->{status}->{name} 
      . ", updated " . Moji::Time::ago($updated);
  
  eval { $comments = @{$issue->{fields}->{comment}->{comments}}; };
      
  if ($comments) {
    my $s = $comments > 1 ? 's' : '';
    $out .= " ($comments comment$s)";
  }
  
  return "$out - $url";
  
}

1;
