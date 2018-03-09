# hdtgm-info 
## A static website for movie stats

This repo generates a set of files that can be used to serve a static website. The data for these files is taken from various sources, and is specific to movies that have been reviewed on the podcast "How Did This Get Made?"

### Configuring the build script

There's one Perl script that loads the current list of episodes from the HDTGM website and generates a JavaScript file of data for the site. The script grabs content from the API of [www.themoviedb.org](http://www.themoviedb.org/), so if you want to run this script on your own site, you will have to create an account, log in, and create an API key to use in the script.

There's a variable in the script called `$THEMOVIEDB_APIKEY`, and you will not be surprised to learn that this is the place where you place your API key. 

### Building the site 

There are a few run-time flag arguments, but right now you can just run the script thusly:

```bash
perl generate.pl -a
```

The script will generate both a regular JavaScript file and a min-ified version. 

### Cache files

The Perl script will also save some data to disk after it's come to a logical ending point. This is to allow you to re-run the script without having to reload all the data from online. Here are the files saved:


* remote-html.txt -- the raw HTML received from the HDTGM website.
* data.csv -- a tab-delimited file that's a parsed version of remote-html.txt.
* cache.pl -- a Perl file that's read in at the start of execution. Several in-memory variables are stored in this file.

And the JavaScript files that will be generated are named hdtgm-data.js and hdtgm-data.min.js.

