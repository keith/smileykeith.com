---
layout: post
title: "Automated Google Reader Backups"
date: 2013-02-01 12:30
---

I spend a lot of time in my RSS [Reeder](http://reederapp.com/) (see what I did there?). I still find Google Reader to be the best and easiest way to manage my subscriptions, although I've been wanting to switch to [Fever](http://feedafever.com/) for a while.

One thing I wanted to do when I launched my new site (the one you're reading) was to have a downloadable up to date export of my Google Reader OPML file (which of course I never did). I looked around for good ways to automate this and I found a simple Python script to do it with (sorry I couldn't find it again for this post). I decided to rewrite it in Ruby and set it up on my server as an automated cron job.

To run the script I came up with use something like:

{% highlight bash %}
ruby path/to/googleReaderOPML.rb username@gmail.com SekretPassword
{% endhighlight %}

To add it to your crontab (to run every Sunday at 1:01am) use something like:
{% highlight bash %}
1 1 * * 7 ruby path/to/googleReaderOPML.rb username@gmail.com SekretPassword
{% endhighlight %}

{% highlight ruby %}
#!/usr/bin/env ruby

#
# => This script will authorize your Google credentials and download your Google Reader subscriptions
# => Usage: ./googleReaderOPML.rb GOOGLEUSERNAME PASSWORD
#

# The required networking shenanigans
require 'uri'
require 'net/http'
require 'open-uri'

require 'rubygems'
# This requires the 'colorize' gem. Install with '[sudo] gem install colorize'
require 'colorize'


# The base Google URLs for callback, authentication, and subscription export
$GOOGLE_URL = "http://www.google.com"
$LOGIN_URL = "https://www.google.com/accounts/ClientLogin"
$READER_URL = "http://www.google.com/reader/subscriptions/export"

# The user agent string, for some reason this is required, feel free to change it
$SOURCE = "keith.so"

# The default output filename, it is automatically overwritten if one already exists
$FILE_NAME = "googlereadersubscriptions.opml"


# Make sure there is the correct number of arguments
if ARGV.count != 2
	# Print the instruction
	puts "Usage: ./#{ File.basename(__FILE__) } USERNAME PASSWORD".red
	exit
end

# Build the request URL
uri = URI.parse($LOGIN_URL)

# Setup the Parameters
params = { Email: ARGV.first, Passwd: ARGV.last, service: "reader", source: $SOURCE, continue: $GOOGLE_URL }

# Add the user-agent string, my website (feel free to replace it) to the headers
headers = { "User-agent" => $SOURCE }

# Encode the parameters into the url
uri.query = URI.encode_www_form(params)

# Create a new NET:HTTP object with the request URL
http = Net::HTTP.new(uri.host, uri.port)

# Require HTTPS without this net/http will not be happy with you
http.use_ssl = true

# Execute the request
request = Net::HTTP::Get.new(uri.request_uri, headers)

# Get the data from the request
response = http.request(request)

# Check for valid response code, should ONLY be 200
if response.code != '200'
	puts "Google returned #{ response.code }, check your username and password".red
	exit
end

# split each token into a different item then load them each into a hash with the key as the token key
auth_hash = Hash.new
response.body.split(/\n/).each do |token|
	split_array = token.split('=')
	auth_hash[split_array.first.downcase] = split_array.last
end

# Create a header hash for the request of the XML file
headers = { "user-agent" => $SOURCE, "cookie" => "Name=SID;SID=#{ auth_hash['sid'] };Domain=.google.com;Path=/;Expires=160000000000", "authorization" => "GoogleLogin auth=#{ auth_hash['auth'] }" }

# Open the URL for the Google Reader export with the setup headers
request = open($READER_URL, headers)

# Open the received XML feeds file
google_reader_file = File.open(request, 'r')

# Read the entire feeds file into 'subscriptions'
subscriptions = google_reader_file.read

# Close the downloaded file
google_reader_file.close()

# Open a new file with the global filename to write to, overwrite it if it exists
subscriptions_file = File.open($FILE_NAME, 'w')

# Verify the file was created
if File.exists?(subscriptions_file)
	# Write the subscriptions to the file and close it
	subscriptions_file.write(subscriptions)
	subscriptions_file.close()

	# Display a success message
	puts "Wrote Google Reader subscriptions to #{ $FILE_NAME }".green
else
	# If the file wasn't created print an error
	puts "Couldn't write to #{ $FILE_NAME } (the process running this script may not have sufficient privileges".red
end
{% endhighlight %}

