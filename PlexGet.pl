#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;
use XML::LibXML;
use XML::Simple;
use File::Path qw( make_path );
use LWP::UserAgent;
use Encode;
use File::HomeDir;
my $configfile = File::HomeDir->my_home . "/.plex.ini";
my $debug = 0;
my %config;
$config{Movielibrary} = "";
$config{TVlibrary} = "";
$config{token} = "";
my $pms = "Plex Media Server";
my $pmsdata;
my @pmslist;
my $count = 0;
my $section;
my $library;
my $token;
my $mainurl;
my $url;
my $mediatype;
my $directory;
my $outputfile;

getSettings();
($mainurl,$token) = getServerList();
print "Server URL: $url : Server Token: $token\n" if ($debug);
($mediatype, $url) = getMediaTypes($mainurl, $token);
print "Mediatype: $mediatype : Server URL: $url" if ($debug);
if ($mediatype eq "movie") {
    ($url, my $title, my $year, my $container) = getMovieURL($url, $token);
	$directory = $config{Movielibrary}.$title." (".$year.")";
	$outputfile = $directory."/".$title." (".$year.").".$container;
	#print "Downloading movie to ".$outputfile."\n";
	if ( !-d $directory ) {
		make_path "$directory" or die "Failed to create path: $directory";
	}
}
elsif ($mediatype eq "show") {
	($url, my $showtitle, my $title, my $year, my $container) = getTVURL($url, $token);
	$directory = $config{TVlibrary}.$showtitle."/".$title;
	$outputfile = $directory."/".$title." (".$year.").".$container;
	#print "Downloading TV show to ".$outputfile."\n";
	if ( !-d $directory ) {
		make_path "$directory" or die "Failed to create path: $directory";
	}	
};
print "$outputfile \n$url\n" if ($debug);
wget($outputfile,$url);
exit;

#==============================================================
#========================= subs ===============================

sub getServerList {
	my $input = -1;
  my $url = "https://plex.tv/api/resources?includeHttps=1&includeRelay=1&X-Plex-Token=".$config{token};
	my $wsdlResponse = HTTP::Tiny->new->get($url);
	$wsdlResponse->{success} or die;
	my $dom = XML::LibXML->load_xml(string => $wsdlResponse->{content});

	foreach my $server ($dom->findnodes('/MediaContainer/Device')) {
		$pmslist[$count]= $server->findvalue('./@name');
		$pmsdata->{name} = $server->findvalue('./@name');
		$pmsdata->{$pmsdata->{name}}->{product} = $server->findvalue('./@product');
		$pmsdata->{$pmsdata->{name}}->{publicAddress} = $server->findvalue('./@publicAddress');
		$pmsdata->{$pmsdata->{name}}->{clientIdentifier} = $server->findvalue('./@clientIdentifier');
		$pmsdata->{$pmsdata->{name}}->{accessToken} = $server->findvalue('./@accessToken');
		foreach my $conn ($server->findnodes('./Connection')) {
				$pmsdata->{$pmsdata->{name}}->{uri} = $conn->findvalue('./@uri');
		}

	$count++;
	}

	## PRINT MENU
	$count = 0;
  print "\n=========================\nPlex Server List\n\n";
	foreach my $server (@pmslist) {
		if ($pmsdata->{$server}->{product} =~ /$pms/) {
			print "$count: $server\n";
		}
		$count++;
	}
  
  while ( ($input !~ /\d/) or ($input == -1) or ($input > $count)  ) {
	  print "Enter your input:\n";
	  $input = <STDIN>;
	  chomp $input;
	}
 
	my $serverurl = $pmsdata->{$pmslist[$input]}->{uri};
	my $servertoken = $pmsdata->{$pmslist[$input]}->{accessToken};
	$url = $serverurl."/library/sections?X-Plex-Token=".$servertoken;
	print "URL: $url\n" if ($debug);
	
	return ($serverurl,$servertoken);
};

sub getMediaTypes {
	my ($serverurl,$servertoken) = @_;
  my $input = -1;
	my $url = $serverurl."/library/sections?X-Plex-Token=".$servertoken;
	my $wsdlResponse = HTTP::Tiny->new->get($url);
	$wsdlResponse->{success} or die;
	my $dom = XML::LibXML->load_xml(string => $wsdlResponse->{content});
	my $count = 0;
	my @key;
    my @type;
	foreach my $list ($dom->findnodes('/MediaContainer/Directory')) {
		print $count.": ".$_->textContent, "\n" for $list->findnodes('./@title');
		push(@key,$list->findvalue('./@key'));
		push(@type,$list->findvalue('./@type'));
		$count++;
	}	
  while ( ($input !~ /\d/) or ($input == -1) or ($input > $count)  ) {
	  print "Enter your input:\n";
	  $input = <STDIN>;
	  chomp $input;
	}
	my $section = $key[$input];
	my $type = $type[$input];
	$url = $serverurl."/library/sections/".$section."?X-Plex-Token=".$servertoken;
	$wsdlResponse = HTTP::Tiny->new->get($url);
	$wsdlResponse->{success} or die;
	$dom = XML::LibXML->load_xml(string => $wsdlResponse->{content});
	$count = 0;
	@key = ();
  $input = -1;
	foreach my $list ($dom->findnodes('/MediaContainer/Directory')) {
		if ( !$list->hasAttribute('secondary')) {
			print $count.": ".$_->textContent, "\n" for $list->findnodes('./@title') ;
			push(@key,$list->findvalue('./@key'));
			$count++;
		}
	}
  while ( ($input !~ /\d/) or ($input == -1) or ($input > $count)  ) {
	  print "Enter your input:\n";
	  $input = <STDIN>;
	  chomp $input;
	}
  print "You typed: $input\n" if ($debug);
	$url = $serverurl."/library/sections/".$section."/".$key[$input]."?X-Plex-Token=".$servertoken;

	print "URL: $url\n" if ($debug);
	return ($type, $url);
}

sub getMovieURL {
	my ($serverurl,$servertoken) = @_;
	my @key = ();
	my $input = -1;
  my @title;
	my @year;
	my @container;
	my @size;
	my $wsdlResponse = HTTP::Tiny->new->get($serverurl);
	$wsdlResponse->{success} or die;
	my $dom = XML::LibXML->load_xml(string => $wsdlResponse->{content});
	my $count = 0;

	foreach my $list ($dom->findnodes('/MediaContainer/Video')) {
		my $size = "Unknown";
    $size = sprintf "%.2f", ($list->findvalue('./Media/Part/@size') / 1073741824) if ($list->findvalue('./Media/Part/@size') ne "");	
		push(@key,$list->findvalue('./Media/Part/@key'));
		push(@title,$list->findvalue('./@title'));
		push(@year,$list->findvalue('./@year'));
		push(@container,$list->findvalue('./Media/Part/@container'));
		push(@size,$list->findvalue('./Media/Part/@size'));
		print "$count : ".$list->findvalue('./@title')." (".$size." GB)\n";
		#    print $_->textContent, "\n" for $list->findnodes('./Media/Part/@key');
		$count++;
	}
  while ( ($input !~ /\d/) or ($input == -1) or ($input > $count)  ) {
	  print "Enter your input:\n";
	  $input = <STDIN>;
	  chomp $input;
	}
  print "You typed: $input\n" if ($debug);
#	my $directory = $library.$title[$input]." (".$year[$input].")";
#	my $outputfile = $directory."/".$title[$input]." (".$year[$input].").".$container[$input];
#	print "Title chosen: ".$outputfile." (size: ".$size[$input].")\n";
#	if ( !-d $directory ) {
#		make_path "$directory" or die "Failed to create path: $directory";
#	}
	$url = $mainurl.$key[$input]."?download=1&X-Plex-Token=".$servertoken;
#	my $curlcmd = "curl -s $url -o '$outputfile'";
#	my $wgetcmd = "wget -c -q --show-progress -O '$outputfile' $url";
    return($url,$title[$input],$year[$input],$container[$input]);
	#wget($outputfile,$url);
};

sub getTVURL {
	my ($serverurl,$servertoken) = @_;
	my @key = ();
	my @title;
	my @showtitle;
	my @year;
	my @container;
	my @size;
	my $input = -1;
  my $wsdlResponse = HTTP::Tiny->new->get($serverurl);
	$wsdlResponse->{success} or die;
	my $dom = XML::LibXML->load_xml(string => $wsdlResponse->{content});
	my $count = 0;

	foreach my $list ($dom->findnodes('/MediaContainer/Video')) {
		my $size = sprintf "%.2f", ($list->findvalue('./Media/Part/@size') / 1073741824);	
		push(@key,$list->findvalue('./Media/Part/@key'));
		push(@title,$list->findvalue('./@title'));
		push(@showtitle,$list->findvalue('./@grandparentTitle'));
		push(@year,$list->findvalue('./@year'));
		push(@container,$list->findvalue('./Media/Part/@container'));
		push(@size,$list->findvalue('./Media/Part/@size'));
		print "$count : ".$list->findvalue('./@grandparentTitle')." - ".$list->findvalue('./@title')." (".$size." GB)\n";
		#    print $_->textContent, "\n" for $list->findnodes('./Media/Part/@key');
		$count++;
	}
  while ( ($input !~ /\d/) or ($input == -1) or ($input > $count)  ) {
	  print "Enter your input:\n";
	  $input = <STDIN>;
	  chomp $input;
	}
  print "You typed: $input\n" if ($debug);
#	my $directory = $library.$title[$input]." (".$year[$input].")";
#	my $outputfile = $directory."/".$title[$input]." (".$year[$input].").".$container[$input];
#	print "Title chosen: ".$outputfile." (size: ".$size[$input].")\n";
#	if ( !-d $directory ) {
#		make_path "$directory" or die "Failed to create path: $directory";
#	}
	$url = $serverurl.$key[$input]."?download=1&X-Plex-Token=".$servertoken;
#	my $curlcmd = "curl -s $url -o '$outputfile'";
#	my $wgetcmd = "wget -c -q --show-progress -O '$outputfile' $url";
    #return($url,$outputfile);
	return($url,$showtitle[$input],$title[$input],$year[$input],$container[$input]);
	#wget($outputfile,$url);
};


sub wget {
    my $log_f = '/tmp/plexwget.log';
    my ($outputfile,$url) = @_;

    $SIG{INT} = sub { unlink $log_f; exit };
    if (my $pid = fork) {
    system "wget -o $log_f --progress=bar:force -c -O '$outputfile' '$url'";
    } else {
    die "cannot fork: $!" unless defined $pid;
    }

    sleep 1 until -f $log_f;

    open LOG, $log_f or die "Couldn't open '$log_f': $!\n";

    my ($pos, $length, $status);
    while (1) {
    for ($pos = tell LOG; $_ = <LOG>; $pos = tell LOG) {
        s/^\s+//;
		if (/^Length: ([\d,]+)/) {
			print "Downloading: $outputfile [$1] bytes.\n";
        } 
		elsif (/^.{19}\s+\d+%/) {
			print "$_\r";
			$status = 'downloading';
        } 
		elsif (defined $status eq 'downloading' and !/^\d+%/) {
			unlink $log_f;
			print "\n";
			last;
        }		
    }

    sleep 1;
    seek LOG, $pos, 0;
    }
}

sub getSettings {
   my $movies;
   my $tvshows;
   my $apptoken;
   my $plexuser = "";
   my $plexpass = "";
   if (-e $configfile) {
     open(FILE,"<$configfile") or die "Can't open configuration file $configfile\n" ;
     while (<FILE>) {
       chomp;       
  	   if (/^(\w+) *= *(.+)$/) {
	       $config{$1} = $2;
       }
      }
      close FILE;
   }
	if ( ($config{Movielibrary} !~ /\w/ ) or ($config{TVlibrary} !~ /\w/) ) {	   
     print "\n========================\nThe following configuration needs to be set:\n";
	   print "Movielibrary - local directory to download movies\nTVlibrary - local directory to download TV shows\n";
     while ($config{Movielibrary} !~ /\w/) {
          print "\nWhere do you want to store downloaded Movies?\n";
          $config{Movielibrary} = <STDIN>;
          chomp $config{Movielibrary};
     }
	   while ($config{TVlibrary} !~ /\w/) {
 	       print "\nWhere do you want to store downloadaed TV shows:\n";
	       $config{TVlibrary} = <STDIN>;
	       chomp $config{TVlibrary};
     }         
	}
  
  if ($config{token} !~ /\w/) {
 	    print "\n=========================\nGenerating token for PlexGet\n";
      while ($plexuser !~ /\w/) {
         print "Enter your plex username:\n";
	       $plexuser = <STDIN>;
        chomp $plexuser;
      }
 	    while ($plexpass !~ /\w/) {
         print "\nEnter your plex password:\n";
	      $plexpass = <STDIN>;	      
        chomp $plexpass;    
      }  
      $config{token} = &myPlexToken($plexuser,$plexpass);
  }
  $config{Movielibrary} =~ s|/?$|/|;
  $config{TVlibrary} =~ s|/?$|/|;
  open(FILE,">$configfile") or die "Can't open configuration file $configfile\n";
  print FILE "token = ".$config{token}."\n";
  print FILE "Movielibrary = ".$config{Movielibrary}."\n";
  print FILE "TVlibrary = ".$config{TVlibrary}."\n";
  close FILE;
        
}

sub myPlexToken() {
    my $appname = "PlexGet";
    my ($myPlex_user,$myPlex_pass) = @_;
    if (!$myPlex_user || !$myPlex_pass) {
        print "* You MUST specify a myPlex_user and myPlex_pass in the config.pl\n";
        print "\n \$myPlex_user = 'your username'\n";
        print " \$myPlex_pass = 'your password'\n\n";
        exit;
    }
    my $ua = LWP::UserAgent->new(  ssl_opts => {
        verify_hostname => 0,
        
                                   });
    #SSL_verify_mode => SSL_VERIFY_NONE,
    $ua->timeout(20);
    $ua->agent($appname);
    $ua->env_proxy();

    $ua->default_header('X-Plex-Client-Identifier' => $appname);
    $ua->default_header('Content-Length' => 0);

    my $url = 'https://my.plexapp.com/users/sign_in.xml';

    my $req = HTTP::Request->new(POST => $url);
    $req->authorization_basic($myPlex_user, $myPlex_pass);
    my $response = $ua->request($req);

    #print $response->as_string;

    if ($response->is_success) {
        my $content = $response->decoded_content();

        my $data = XMLin(encode('utf8',$content));
        return $data->{'authenticationToken'} if $data->{'authenticationToken'};
        return $data->{'authentication-token'} if $data->{'authentication-token'};
    } else {
        print $response->as_string;
        die;
    }
}
