#!/usr/bin/perl

# generate.pl -- retrieves content from various remote sites to generate JavaScript data files

use strict;

use LWP::UserAgent;
use Data::Dumper;
use URI::Escape;
use Getopt::Std;
use JSON;
use Date::Format;
use Carp;
use HTML::Parser ();
use URI::URL;

binmode STDOUT, ":encoding(UTF-8)";  # might get UTF-8 data

my $THEMOVIEDB_APIKEY = undef; # get API key at https://www.themoviedb.org/
my(%MOVIECACHE) = ();          # title => data
my(%GENRECACHE) = ();		   # genre id => name
my(%YEARCACHE) = ();           # title => year
my(%PERSONCACHE) = ();         # name => ID
my(@GUESTCACHE) = ();          # show # => guest ID
my(@SHOWCACHE) = ();           # show # => movie ID
my(@LIVECACHE) = ();           # show # => bool

my $HELPTEXT = <<FOO;
Usage: generate.pl [ -c ] [ -t ] [ -j ] [ -a ] [ -m ##### ] [ -h ]

  -c  generate blank config file (if none exists)
  -t  generate intermediate text file
  -j  generate end Javascript
  -a  do all steps
  -m  do a lookup for a specific movie title
  -h  print this message

FOO

my $ua = LWP::UserAgent->new( cookie_jar => {} );

$| = 1;


###
### Parsing HTML retrieved from earwolf site.
### The objective is to get the show description,
### which might have a year for the film. (This started
### regularly after around show 120.)
###

my(%PARSEVAR) = ();

my $hp = HTML::Parser->new(
	start_h => [ sub {
		my($tagname,$attr) = @_;
		if ($tagname eq 'div' && $attr->{class} eq 'episodeshowdesc') {
			$PARSEVAR{capture} = 1;
		} elsif ($PARSEVAR{capture} && $tagname eq 'p' && ! $PARSEVAR{data}) {
			$PARSEVAR{para} = 1;
		}
		}, 'tagname,attr' 
		],
	end_h => [ sub { 
		my($tagname) = @_;
		$PARSEVAR{para} = 0 if $tagname eq 'p';
		$PARSEVAR{capture} = 0 if $tagname eq 'div';
		}, 'tagname'
		],
	text_h => [ sub {
		my($text) = @_;
		if ($PARSEVAR{capture} && $PARSEVAR{para}) {
			$PARSEVAR{data} .= $text;
		}
		}, 'text'
		],
	);

sub find_desc {
	my($uri) = @_;
	my $u = URI::URL->new($uri, 'http://www.earwolf.com/');
	my $descresp = $ua->get($u->abs);

	%PARSEVAR = ();
	$hp->parse($descresp->decoded_content);
	return $PARSEVAR{data};
}

#open FIL, '<', 'temp.html' or die $!;
#my $txt = join('', <FIL>);
#close FIL;
#$hp->parse($txt);
#exit 0;


###
### cache.pl contains a number of variables related to the gathered data, and is saved
### periodically so that the program won't have to re-request data that it already has
## 

sub read_cache {
	return if ! -e 'cache.pl';
	my $code = '';
	my $fh;
	open $fh, '<', 'cache.pl' or croak $!;
	binmode $fh, ":encoding(UTF-8)";
	$code = join('',<$fh>);
	close $fh;
	eval $code;
	warn $@ if $@;
}

sub write_cache {
	my $fh;
	open $fh, '>', 'cache.pl' or croak $!;
	binmode $fh, ":encoding(UTF-8)";
	print $fh <<'HDR';
# cache.pl -- machine-generated file of cached values

HDR
	print $fh <<'MID';

# $THEMOVIEDB_APIKEY -- your API key from www.themoviedb.org

MID
	print $fh "\$THEMOVIEDB_APIKEY ||= \"${THEMOVIEDB_APIKEY}\"; # don't set the value if it already exists\n";
	print $fh <<'MID';

# %MOVIECACHE -- cached API results, keyed by movie title

MID
	print $fh Data::Dumper->Dump( [ \%MOVIECACHE ], [ '*MOVIECACHE' ]);
	print $fh <<'MID';

# %GENRECACHE -- genre names

MID
	print $fh Data::Dumper->Dump( [ \%GENRECACHE ], [ '*GENRECACHE' ] );
	print $fh <<'MID';

# %YEARCACHE -- cached year data for disambiguation, keyed by movie title

MID
	print $fh Data::Dumper->Dump( [ \%YEARCACHE ], [ '*YEARCACHE' ]);
	print $fh <<'MID';

# %PERSONCACHE -- map actor name to db id

MID
	print $fh Data::Dumper->Dump( [ \%PERSONCACHE ], [ '*PERSONCACHE' ]);
	print $fh <<'MID';

# @GUESTCACHE -- list of guests on each episode, indexed by show number

MID
	print $fh Data::Dumper->Dump( [ \@GUESTCACHE ], [ '*GUESTCACHE' ]);
	print $fh <<'MID';

# @SHOWCACHE -- movie IDs for each show

MID
	print $fh Data::Dumper->Dump( [ \@SHOWCACHE ], [ '*SHOWCACHE' ]);
	print $fh <<'MID';

# @LIVECACHE -- flags for live shows

MID
	print $fh Data::Dumper->Dump( [ \@LIVECACHE ], [ '*LIVECACHE' ]);
	print $fh <<'FTR';

1;
__END__

FTR
	close $fh;
}

##
## get the HTML containing the list of episodes and save it in CSV format
## 

sub get_remote_html {
	my($movie,$live,$num,@currentlist);
	my $txt;
	my(@MOVIELIST) = ();
	my $fh;

	if (-e 'remote-html.txt' && -M 'remote-html.txt' < 7) { # can have recently retrieved file cached on local disk
		open $fh, '<', 'remote-html.txt' or croak $!;
		$txt = join('',<$fh>);
		close $fh;
	} else {
		my $resp = $ua->get("http://www.earwolf.com/alleps-ajax.php?show=2682");
		croak $resp->status_line unless $resp->is_success;
		$txt = $resp->decoded_content; 
		open $fh, '>', 'remote-html.txt' or croak $!;
		binmode $fh, ':utf8';
		print $fh $txt;
		close $fh;
	}
	while ($txt =~ m{<li>(.+)</li>}gm) {
		$movie = ''; @currentlist = (); 
		my $l = $1;
		next if $l =~ m{Minisode}  # skip mini episodes
         || $l =~ m{Ep \x23\d+\.}     # skip other in-between episodes
		 || $l =~ m{Ep \x23\D}        # skip non-numbered episodes
		 ;

		if ($l =~ m{Ep \x23(\d+)}) { $num = $1; $LIVECACHE[$num] = 0; }
		if ($l =~ m{<a href="(.+)">(.+)</a>}) {
			print "\t1 = $1, 2 = $2\n";
			my $uri = $1;
			$movie = $2;

			if ($movie =~ m{\s+\(.+\)$}) { $movie = $`; }
			if ($movie =~ m{:? LIVE}) { $LIVECACHE[$num] = 1; $movie = $`; }
			push @currentlist, $movie;

			push @currentlist, find_desc($uri);

		} else { warn "no movie found in this line: $l" }
		while ($l =~ m{<span>([^<]+)</span>}g) { push @currentlist, $1; }
		$MOVIELIST[$num] = [ @currentlist ];
	}
	write_cache();
	open $fh, '>', 'data.csv' or croak $!;
	binmode $fh, ":utf8";
	for (my $iter = 1; $iter < scalar @MOVIELIST; ++$iter) {
		printf $fh "%s\n", join("\t", ($iter, @{$MOVIELIST[$iter]}));
	}
	close $fh;
	exit 0;
}

## 
## given an arrayref, return a unique-items-only copy
##

sub uniq {
	my($a) =@_;
	my(%SEEN,$retval);
	$retval = [];
	foreach (@$a) {
		push @$retval, $_ unless $SEEN{$_};
		$SEEN{$_} = 1;
	}
	return $retval;
}

## 
## read the previously generated CSV file 
## 

my $changed = 0;

sub parse_csv {
	my $fh;
	open $fh, '<', 'data.csv' or croak $!;
	binmode $fh, ":utf8";
	while (! eof $fh) {
		$changed = 0;
		chomp(my $line = <$fh>);
		my @field = split(/\t/, $line);
		my $num = shift @field;
		my $title = shift @field;
		my $desc = shift @field; 
		$desc =~ s{&\x23821(6|7);}{'}g;
		$desc =~ s{&\x23822(0|1);}{"}g;
		$desc =~ s{&\x238230;}{...}g;
		$desc =~ s{&\x238211;}{-}g;

		$title = clean_title($title);
		next if $title =~ m{Howdies};  # special episode recognition
		next if $title eq 'Zardoz 2';
		printf("%3d . %s\n", $num, $title);
		#printf("%3d . %s\n%s\n\n", $num, $title, $desc); exit 0;

		my($foundyear) = undef;
		if ($desc =~ m{\b((19|20)\d\d)\b}) { $foundyear = $1; print "\tfound year $foundyear in show description\n"; }


		my $m = get_movie($title, $YEARCACHE{$title} || $foundyear);

		if ($m eq undef && $foundyear ne '') {
			print "No movie found with specified date, checking plain title\n";
			$m = get_movie($title);
		}

		$SHOWCACHE[$num] = $m->{id};
		if (! $m->{cast}) {
			my $tmp = get_movie_details($m->{id});
			$m->{$_} = $tmp->{$_} foreach keys %$tmp;

		}
		foreach my $p (@field) {
			my $resp = get_person($p);
			if (! $GUESTCACHE[$num]) { $GUESTCACHE[$num] = [ ] ; }
			if ($resp){
				push @{$GUESTCACHE[$num]}, $resp;
				} else {
					warn "unknown person $p\n";
					push @{$GUESTCACHE[$num]}, $p;
					$PERSONCACHE{$p} = $p;
				}
		}
		$GUESTCACHE[$num] = uniq($GUESTCACHE[$num]);
		write_cache() if $changed;
	}
	close $fh;
}


sub throttled_get {  # a call to get() with header checking for throttling
	my($url) = @_;
	my($resp) = $ua->get($url);
	croak $resp->status_line unless $resp->is_success;

	# current rate limit is 40 requests every 10 secs. 
	if ($resp->header('X-RateLimit') < 30) { sleep 1; }
	return $resp->decoded_content;
}

##
## what items to keep from the movie data received through the api?

sub data_subset {
	my($d) = @_;
	my($retval) = {};
	$retval->{$_} = $d->{$_} foreach qw(title release_date poster_path id genre_ids);
	return $retval;
}

sub clean_title {
	my($t) = @_;
	# A place to remove any notations from the title

	$t =~ s{Director's Edition: }{};
	$t =~ s{: Director's Edition}{};
	return $t;
}

sub compare_titles {
	my($t1,$t2) = @_;
	return 1 if lc $t1 eq lc $t2; # should take care of majority of titles

	if ($t1 =~ m{\&|and}i && $t2 =~ m{\&|and}i) {  # Tango & Cash, Mac & Me
		my($t1_copy) = $t1; $t1_copy =~ s{\s*(\&|and)\s*}{ }i;
		my($t2_copy) = $t2; $t2_copy =~ s{\s*(\&|and)\s*}{ }i;
		return 1 if lc $t1_copy eq lc $t2_copy;
	}
	if ($t1 =~ m{[/:\!]} || $t2 =~ m{[/:\!]}) { # some troublesome punctuation
		my $t1_copy = $t1; $t1_copy =~ y{/:!}{   }s;
		my $t2_copy = $t2; $t2_copy =~ y{/:!}{   }s;
		$t1_copy =~ s{\s+}{ }g;
		$t2_copy =~ s{\s+}{ }g;
		return 1 if lc $t1_copy eq lc $t2_copy;
	}
	return 0;
}


##
## The retrieval of any details that might be worth graphing out will go in here. Mainly used for cast.
##

sub get_movie_details {
	my($mid) = @_;
	my($retval) = { cast => [ ] };
	my $obj = undef;

	my $url = 'https://api.themoviedb.org/3/movie/'.$mid . '/credits?api_key='.$THEMOVIEDB_APIKEY;
	my $resp = throttled_get $url;
	eval { $obj = decode_json $resp };
	warn $@ if $@;
	foreach my $p (@{$obj->{cast}}) {
		if (! $PERSONCACHE{$p->{name}}) {
			$PERSONCACHE{$p->{name}} = $p->{id};
		}
		push @{$retval->{cast}}, $p->{id};
	}

	$url = 'https://api.themoviedb.org/3/movie/'.$mid . '?api_key='.$THEMOVIEDB_APIKEY;
	$resp = throttled_get $url;
	eval { $obj = decode_json $resp };
	warn $@ if $@;
	$retval->{budget} = $obj->{budget};
	$retval->{revenue} = $obj->{revenue};
	#print Dumper($retval); exit 0;
	return $retval;
}

##
## given a movie title and an optional year (used for disambiguation), return a bare-bones collection of data
## given out by the search. TODO - fold in the additional data from 'get_movie_details'
## 

sub get_movie {
	my($title, $year) = @_;
	if ($MOVIECACHE{$title}) {
		return $MOVIECACHE{$title};
	} else {
		$changed = 1; # need to write the cache after this code 

		my $url = 'https://api.themoviedb.org/3/search/movie?'.
			'api_key='.$THEMOVIEDB_APIKEY.'&'.
			'language=en-US&'.
			'query='.uri_escape($title).'&'.
			'include_adult=false';
		if ($year) { $url .= '&year='.$year; }
		my $result = throttled_get $url;
		my $j; eval { $j = decode_json $result; };
		if ($@) {
			warn "Couldn't look up movie $title: $@";
			return undef;
		}
		#print Dumper($j); exit 0;

		if ($j->{total_results} == 0) {
			warn "No results from searching for $title";
			return undef;
		}
		if ($j->{total_results} == 1) { 
			my $t = $j->{results}->[0];
			$MOVIECACHE{$title} = data_subset($t);
			return $MOVIECACHE{$title};
		} else {
			my(@results) = ();
			push @results, $_ foreach @{$j->{results}};
			while ($j->{total_pages} > 1 && $j->{page} < $j->{total_pages}) {
				print "Retrieving page " . ($j->{page} + 1) . " of $j->{total_pages}\n";
				my $urlplus = $url . "&page=" . ($j->{page} + 1);
				$result = throttled_get $urlplus;
				eval { $j = decode_json $result; };
				if ($@) {
					warn "Couldn't look up movie title: $@";
					return undef;
				}
				push @results, $_ foreach @{$j->{results}};
			}

			if (scalar @results > 25 && ! $year) {
				print "Search results returned " . scalar(@results). " potential titles for '$title'.\n";
				print "Enter the year for this movie to filter out incorrect titles (just hit Enter to skip): ";
				chomp(my $in = <STDIN>);
				if ($in > 1900) { $year = $in; }
			}

			if ($year) { # return specific item from specific year
				@results = grep { substr($_->{release_date},0,4) == $year } @results;
			}

			# check for one record with exact title
			my $located = 0; my $last = undef;
			foreach my $i (@results) {
				if (compare_titles($i->{title}, $title)) { # Case insensitive compare
					++$located; $last = $i;
				}
			}
			if ($located == 1) {
				print "Found exactly 1 matching movie.\n";
				$MOVIECACHE{$title} = data_subset($last);
				return $MOVIECACHE{$title};
			}

			my(@yearcache) = ();
			warn "Searching for movie $title came up with ".@{$j->{results}}." different titles, from these years:\n";
			for (my $iter = 0; $iter < scalar @{$j->{results}}; ++$iter) {
				$j->{results}->[$iter]->{release_date} =~ m{(\d\d\d\d)};
				$yearcache[$iter] = $1;
				printf("[%d] %s (%d)\n", $iter+1, $j->{results}->[$iter]->{title}, $yearcache[$iter]);
			}
			print "Enter a number of movie to use here (empty string means the first choice)\n";
			chomp(my $in = <STDIN>);
			$in = 1 if $in eq '';
			if ($in >= 1 && $in <= scalar @{$j->{results}}) {
				--$in;
				$MOVIECACHE{$title} = data_subset($j->{results}->[$in]);
				$YEARCACHE{$title} = $yearcache[$in];
				print "Selecting ".$MOVIECACHE{$title}->{title} . " (" . $yearcache[$in] . ")\n";
				return $MOVIECACHE{$title};
			} else { write_cache(); croak "aborting."}
		}
	}
}


## 
## genre list from TMDB

sub get_genre_list {
	return if keys %GENRECACHE > 0;
	my $url = 'https://api.themoviedb.org/3/genre/movie/list?api_key='.$THEMOVIEDB_APIKEY;
	my $resp = throttled_get $url;
	my $j = undef; eval { $j = decode_json $resp; };
	if ($@) { warn $@; return undef; }
	foreach my $e (@{$j->{genres}}) { $GENRECACHE{$e->{id}} = $e->{name}; }
}

## 
## retrieve data about people in these movies
## 

sub get_person {
	my($p) = @_;
	if ($PERSONCACHE{$p} ne undef) {
		return $PERSONCACHE{$p};
	} else {
		my $url = 'https://api.themoviedb.org/3/search/person?'.
			'api_key='.$THEMOVIEDB_APIKEY.'&'.
			'language=en-US&'.
			'query='.uri_escape($p).'&'.
			'include_adult=false';
		my $resp = throttled_get $url;
		my $j = undef; eval { $j = decode_json $resp; } ;
		if ($@) { warn $@; return undef; }
		if ($j->{total_results} == 1) {
			$PERSONCACHE{$p} = $j->{results}->[0]->{id};
			return $j->{results}->[0]->{id};
		} elsif ($j->{total_results} == 0) {
			return undef;
		} else {  # multiple people

			foreach my $p (@{$j->{results}}) {  # check if any of the person IDs has already been seen
				foreach my $v (values %PERSONCACHE) {
					if ($v == $p->{id}) {
						$PERSONCACHE{$p} = $v;
						return $v;
					}
				}
			}

			my($MAXCREDITS) = 0;
			my($this) = undef;
			foreach my $p (@{$j->{results}}) {
				if (scalar @{$p->{known_for}} > $MAXCREDITS) {
					$MAXCREDITS = scalar @{$p->{known_for}};
					$this = $p;
				}
			}
			if ($this ne undef) {
				$PERSONCACHE{$p} = $this->{id};
				return $this->{id};
			}
		}
		return undef;
	}
}

sub save_js {
	my $json = JSON->new->allow_nonref;

	my(@OUTPUT) = ();
	for (my $iter = 1; $iter < @SHOWCACHE; ++$iter) {
		$OUTPUT[$iter] = {
			movie => $SHOWCACHE[$iter],
			guests => $GUESTCACHE[$iter],
			live => $LIVECACHE[$iter],
		};
	}
	open my $fh, '>', 'hdtgm-data.js' or croak $!;
	binmode $fh, ":encoding(UTF-8)";
	print $fh "var generateDate = '" .time2str("%C",time). "';\n\n";
	print $fh "var SHOWS = " .
		$json->pretty->encode(\@OUTPUT).
		";\n";
	print $fh "var PEOPLE = [];\n";
	while (my($key,$val) = each %PERSONCACHE) {
		print $fh "PEOPLE[".$val."] = " . $json->encode($key) . ";\n"
			if int($val) > 0;
	}
	print $fh "\nvar MOVIES = [];\n";
	foreach my $v (values %MOVIECACHE) {
		my $id = $v->{id}; 
		delete $v->{id};
		print $fh "MOVIES[".$id."] = " . $json->encode($v) . ";\n";
		$v->{id} = $id;
	}
	print $fh "\nvar GENRES = [];\n";
	foreach my $k (keys %GENRECACHE) { printf($fh "GENRES.push({ 'id': %d, 'label': '%s'});\n", $k, $GENRECACHE{$k}); }

	close $fh;
	$json->pretty(0);
	open $fh, '>', 'hdtgm-data.min.js' or croak $!;
	binmode $fh, ":encoding(UTF-8)";
	print $fh "var generateDate='" .time2str("%C",time). "';";
	print $fh "var SHOWS=" .
		$json->encode(\@OUTPUT).
		";";
	print $fh "var PEOPLE=[];";
	while (my($key,$val) = each %PERSONCACHE) {
		print $fh "PEOPLE[".$val."]=" . $json->encode($key) . ";"
		  if int($val) > 0;
	}
	print $fh "var MOVIES=[];";
	foreach my $v (values %MOVIECACHE) {
		my $id = $v->{id}; 
		delete $v->{id};
		print $fh "MOVIES[".$id."]=" . $json->encode($v) . ";";
		$v->{id} = $id;
	}
	print $fh "var GENRES=[];";
	foreach my $k (keys %GENRECACHE) { printf($fh "GENRES.push({'id':%d,'label':'%s'});", $k, $GENRECACHE{$k}); }
	close $fh;
}



###
### MAIN CODE
###

our($opt_t,$opt_j,$opt_a,$opt_h,$opt_c,$opt_m);
getopts('tjahcm:');

if ($opt_h || ! ($opt_t || $opt_j || $opt_a || $opt_m || $opt_c)) {
	print $HELPTEXT;
	exit 0;
}

if ($opt_c) {
	if (-e 'cache.pl') {
		warn "cache.pl exists, so I won't write a new file. Delete the existing file if you want a blank cache.pl file.\n";
	} else {
		write_cache();
		print "cache.pl written.\n";
	}
	exit 0;
}

read_cache();

if ($THEMOVIEDB_APIKEY eq '') {
	warn "You need to provide the API key in cache.pl. See docs for details.\n";
	exit 1;
}
get_genre_list();

if ($opt_m) {
	my $md = get_movie($opt_m);
	if ($md->{id}) {
		my $md2 = get_movie_details($md->{id});
		#print Dumper($md2);
		$md->{$_} = $md2->{$_} foreach keys %$md2;
	}
	print Dumper($md);
	exit 0;
}

if ($opt_t || $opt_a || ($opt_j && ! -e 'data.csv')) {
	get_remote_html() if ! -f 'data.csv' or -M 'remote-html.txt' < -M 'data.csv';
	parse_csv();
}

if ($opt_j || $opt_a) {
	save_js();
}

write_cache();

__END__
