package Moji::Time;

use strict;
use warnings;

require Exporter;
our @ISA         = qw/ Exporter /;
our @EXPORT_OK   = qw/ parse ago /;

use DateTime::Format::Strptime;
use DateTime::Format::Duration;

sub parse {
  
  my $time = shift;
  
  my $dp = DateTime::Format::Strptime->new(
      pattern => ($time =~ m/Z/ ? 
      '%Y-%m-%dT%H:%M:%S' : 
      '%Y-%m-%dT%H:%M:%S.%N%z')); 
  
  return $dp->parse_datetime($time);
  
}

# How long ago was a DateTime?

sub ago {

  my $dur = DateTime->now() - shift;
  
  my $months = $dur->months();
  my $weeks = $dur->weeks();
  my $days = $dur->days();
  my $hours = $dur->hours();
  my $minutes = $dur->minutes();
  my $seconds = $dur->seconds();
  my $s;
  
  if ($months) {
    $s = $months > 1 ? 's' : '';
    return "$months month$s ago"
  }
  if ($weeks) {
    $s = $weeks > 1 ? 's' : '';
    return "$weeks week$s ago"
  }
  if ($days) {
    $s = $days > 1 ? 's' : '';
    return "$days day$s ago"
  }
  if ($hours) {
    $s = $hours > 1 ? 's' : '';
    return "$hours hour$s ago"
  }
  if ($minutes) {
    $s = $minutes > 1 ? 's' : '';
    return "$minutes minute$s ago"
  }
  if ($seconds) {
    $s = $seconds > 1 ? 's' : '';
    return "$seconds second$s ago"
  }

  return "just now";

}

1;
