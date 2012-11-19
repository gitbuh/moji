package Moji::Net;

use strict;
use warnings;

require Exporter;
our @ISA         = qw/ Exporter /;
our @EXPORT      = qw/ shorten_url get_json get_xml /;

use IO::Socket::SSL;
use IO::Socket::INET;
use XML::Simple;
use JSON;

# JSON parser
my $json = new JSON;

# XML parser
# setting KeyAttr prevents id elements from becoming keys of parent elements.
my $xml = new XML::Simple(KeyAttr => 'xxxx');

# Shorten a URL using goo.gl
# https://developers.google.com/url-shortener/v1/getting_started
  
sub shorten_url {

  my $url = shift;
  
  my %request = ( longUrl => $url );
  
  my $data = encode_json(\%request);
  
  my $response = http(
    POST => 'https://www.googleapis.com/urlshortener/v1/url', 
    ( "Content-Type: application/json" ),
    $data
  );
  
  eval {

    my $obj = $json->decode($response);
    
    $url = $obj->{id};
    
  };
  
  return $url;
    
}

# Get JSON from a URL

sub get_json {

  my ($url, $auth) = @_;
  my $hash = {};
  my $response = !$auth ? http(GET => $url) : 
      http(GET => $url, ( "Authorization: Basic $auth" ));
      
  eval { $hash = $json->decode($response) };
  
  return $hash;
}

# Get XML from a URL

sub get_xml {

  my ($url, $auth) = @_;
  my $hash = {};
  my $response = !$auth ? http(GET => $url) : 
      http(GET => $url, ( "Authorization: Basic $auth" ));
  
  eval { $hash = $xml->XMLin($response); };
  
  return $hash;
}

# Do http(s) stuff.
# Warning: fragile.

sub http {
  
  my ($action, $url, $headers, $body) = @_;
  
  my ($protocol, $domain) = $url =~ m#^(https?)://([^/]*)#i;
  
  my $socket = $protocol eq 'https' ? 
      new IO::Socket::SSL("$domain:https") :
      new IO::Socket::INET("$domain:http");

  return warn "Can't open socket to $domain over $protocol.\n" if !$socket;

  my $length = $body ? length $body : 0;
  
  my $br = "\r\n"; # nothing to see here...
  
  my $header_data = $headers ? $br . join $br, $headers : '';
  
  my $request = "$action $url HTTP/1.0$header_data$br"
      . ($length ? "Content-Length: $length$br$br$body" : $br);
  
  my $response;
    
  print $socket $request;
  
  # TODO: won't actually work with plain HTTP, needs a length arg
  $socket->read($response);  
  
  close $socket;
  
  $response =~ s/.*$br$br//ms; # strip the headers from the response
  
  return $response;

}

1;
