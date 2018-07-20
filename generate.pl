#!/usr/bin/perl

# generate.pl -- retrieves content from various remote sites to generate JavaScript data files

use strict;

use LWP::Simple;
use Data::Dumper;
use URI::Escape;
use Getopt::Std;
use JSON;
use Date::Format;

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

###
### cache.pl contains a number of variables related to the gathered data, and is saved
### periodically so that the program won't have to re-request data that it already has
## 

sub read_cache {
	return if ! -e 'cache.pl';
	my $code = '';
	my $fh;
	open $fh, '<', 'cache.pl' or die $!;
	binmode $fh, ":encoding(UTF-8)";
	$code = join('',<$fh>);
	close $fh;
	eval $code;
	warn $@ if $@;
}

sub write_cache {
	my $fh;
	open $fh, '>', 'cache.pl' or die $!;
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
		open $fh, '<', 'remote-html.txt' or die $!;
		$txt = join('',<$fh>);
		close $fh;
	} else {
		$txt = get "http://www.earwolf.com/alleps-ajax.php?show=2682"; 
		open $fh, '>', 'remote-html.txt' or die $!;
		print $fh $txt;
		close $fh;
	}
	while ($txt =~ m{<li>(.+)</li>}gm) {
		$movie = ''; @currentlist = (); 
		my $l = $1;
		next if $l =~ m{Minisode}  # skip mini episodes
         || $l =~ m{Ep #\d+\.}     # skip other in-between episodes
		 || $l =~ m{Ep #\D}        # skip non-numbered episodes
		 ;

		if ($l =~ m{Ep #(\d+)}) { $num = $1; $LIVECACHE[$num] = 0; }
		if ($l =~ m{<a href=".+">(.+)</a>}) {
			$movie = $1;
			if ($movie =~ m{\s+\(.+\)$}) { $movie = $`; }
			if ($movie =~ m{:? LIVE}) { $LIVECACHE[$num] = 1; $movie = $`; }
			push @currentlist, $movie;
		} else { warn "no movie found in this line: $l" }
		while ($l =~ m{<span>([^<]+)</span>}g) { push @currentlist, $1; }
		#printf("%3d : %s\n", $num,join(' / ', @currentlist));
		$MOVIELIST[$num] = [ @currentlist ];
	}
	open $fh, '>', 'data.csv' or die $!;
	binmode $fh, ":encoding(UTF-8)";
	for (my $iter = 1; $iter < scalar @MOVIELIST; ++$iter) {
		printf $fh "%s\n", join("\t", ($iter, @{$MOVIELIST[$iter]}));
	}
	close $fh;
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

sub parse_csv {
	my $fh;
	open $fh, '<', 'data.csv' or die $!;
	binmode $fh, ":encoding(UTF-8)";
	while (! eof $fh) {
		chomp(my $line = <$fh>);
		my @field = split(/\t/, $line);
		my $num = shift @field;
		my $title = shift @field;
		$title = clean_title($title);
		next if $title =~ m{Howdies};
		next if $title eq 'Zardoz 2';
		printf("%3d . %s\n", $num, $title);
		my $m = get_movie($title, $YEARCACHE{$title});
		#print Dumper($m); exit 0;
		$SHOWCACHE[$num] = $m->{id};
		if (! $m->{cast}) {
			my $tmp = get_movie_details($m->{id});
			#$m->{cast} = $tmp->{cast};
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
	}
	close $fh;
}

##
## an attempt to prevent the requests from blowing through the API request limit
## 

my($recentReqs) = 0;

sub throttled_get {  # a call to get() with pauses inserted every few requests, due to API limitations
	my($url) = @_;
	#print "\t$recentReqs\n$url\n"; exit 0;
	my $result = get $url;
	++$recentReqs;
	if ($recentReqs >= 40) {  ## just sleep for a timeout period
		print "timeout limit reached, sleeping\n";
		sleep 10;
		$recentReqs = 0;
	}
	if ($result eq '') { write_cache();  die "didn't get content!\n\$url = $url\n"; }
	return $result;
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

		if ($j->{total_results} == 0) {
			warn "No results from searching for $title";
			return undef;
		}
		if ($j->{total_results} == 1) { 
			my $t = $j->{results}->[0];
			$MOVIECACHE{$title} = data_subset($t);
			return $MOVIECACHE{$title};
		} else {
			if ($year) { # return specific item from specific year
				my $count = 0; my $last = undef;
				foreach my $i (@{$j->{results}}) {
					if (compare_titles($i->{title}, $title) && substr($i->{release_date},0,4) == $year) {
						$MOVIECACHE{$title} = data_subset($i);
						return $MOVIECACHE{$title};
					} elsif (substr($i->{release_date},0,4) == $year) {
						++$count; $last = $i;
					}
				}
				if ($count == 1) {
					$MOVIECACHE{$title} = data_subset($last);
					return $MOVIECACHE{$title};
				}
			}

			# check for one record with exact title
			my $located = 0; my $last = undef;
			foreach my $i (@{$j->{results}}) {
				if (compare_titles($i->{title}, $title)) { # Case insensitive compare
					++$located; $last = $i;
				}
			}
			if ($located == 1) {
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
			} else { die "aborting."}
			#foreach my $r (@{$j->{results}}) {
			#	$r->{release_date} =~ m{(\d\d\d\d)};
			#	print "\t- " . $r->{title} . ' ('.$1.")\n";
			#}
			#print "Add an appropriate entry in the \%YEARCACHE variable in cache.pl to resolve this ambiguation:\n\n\t'$title' => 2010,  # or whatever\n\n";
			#write_cache();
			#exit 0;
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
	open my $fh, '>', 'hdtgm-data.js' or die $!;
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
	open $fh, '>', 'hdtgm-data.min.js' or die $!;
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

if ($opt_h || ! ($opt_t || $opt_j || $opt_a || $opt_m)) {
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
	get_remote_html();
	parse_csv();
}

if ($opt_j || $opt_a) {
	save_js();
}

write_cache();

__END__
