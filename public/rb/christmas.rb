#!/usr/bin/env ruby
#
# A simple example app using the Socrata Open Data API and the Tropo IVR API
# - http://dev.socrata.com
# - http://www.tropo.com
#
# For more details: http://dev.socrata.com/blog/2010/10/28/making-government-data-accessible-by-phone-using-soda-and-tropo/
#

require 'net/http'
require 'json'

# A generic class that allows us easier access to row data
class Entry
  def self.setup(columns)
    # Build up a map of column name -> index so we can access them by name
    @@col_map = (0...columns.size).inject({}) { |memo, idx|
      memo[columns[idx]["name"]] = idx
      memo
    }
  end

  def initialize(entry)
    @entry = entry
  end

  def [](name)
    return @entry[@@col_map[name]]
  end
end

# Look up facilities given a zip code and type
def lookup_facilities(zip_code)
  # This looks complicated, but I'm just building the hash that I'll convert to
  # JSON in order to run a dynamic filter against the Socrata API.
  query = {
    # The 4-4 view ID of the ID I want to filter against
    "originalViewId" => "zqwi-c5q3",

    # A temporary name for my filter
    "name" => "What do I do with",

    # The heart of the matter - our filter hash
    "query" => {
      "filterCondition" => {
        "type" => "operator",

        # We want to filter on the "AND" of two conditions
        "value" => "AND",
        "children" => [ {
          # The first condition checks that the "Zip Code" column matches the
          # zip code that was passed in
          "type" => "operator",
          "value" => "EQUALS",
          "children" => [ {
            "columnId" => 2571137,
            "type" => "column"
          }, {
            "type" => "literal",
            "value" => zip_code
          } ]
        }, {
          # The second condition filter to only return entries for facilities
          # that accept "Yard Waste"
          "type" => "operator",
          "value" => "EQUALS",
          "children" => [ {
            "columnId" => 2571122,
            "type" => "column"
          }, {
            "type" => "literal",
            "value" => "Yard Waste"
          } ]
        } ]
      }
    }
  }

  # Here we just set up a simple Net::HTTP POST request including our query and
  # a content-type
  request = Net::HTTP::Post.new("/api/views/INLINE/rows.json?method=index")
  request.body = query.to_json
  request.content_type = "application/json"
  response = Net::HTTP.start("www.datakc.org", 80){ |http| http.request(request) }

  if response.code != "200"
    log "Error code: #{response.code}"
    log "Body: #{response.body}"
    raise "An error has occurred. I\'m very sorry. Please don\'t hate me."
  else
    body = JSON::parse(response.body)
    Entry.setup(body["meta"]["view"]["columns"])
    return JSON::parse(response.body)["data"].collect{ |row| Entry.new(row) }
  end
end

# Handles phone requests
def phone(zip_code)
  begin
    facilities = lookup_facilities(zip_code)
    if facilities.nil? || facilities.size <= 0
      say "Sorry, I did not find any matches in your area. Please try another zip code."
    else
      say "I found #{facilities.size} #{facilities.size > 1 ? "matches" : "match"} in your zip code. I'll read them to you now."
      say facilities.map{ |r| "#{r["Provider Name"]} at #{r["Provider Address"]} in #{r["City"]}. Their hours are #{r["Hours"].strip}." }.join(" Or, ")
    end
  rescue Exception => e
    say e.message
  end
end

# Handles message requests
def message(zip_code)
  begin
    facilities = lookup_facilities(zip_code)
    if facilities.nil? || facilities.size <= 0
      say "I did not find any matches in your area. Please try another zip code."
    else
      say "Found #{facilities.size} #{facilities.size > 1 ? "matches" : "match"} in your zip code:"
      facilities.each do |f|
        say "#{f["Provider Name"]} at #{f["Provider Address"]} in #{f["City"]}. Hours: #{f["Hours"]}"
      end
    end
  rescue Exception => e
    say "An error has occurred. I'm sorry for the trouble."
    log e.message
  end
end

answer
sleep(2)

# Decide whether this is text or phone
if $currentCall.nil?
  log "Curious. No currentCall. Am I running outside Tropo?"
elsif $currentCall.initialText.nil?
  # Phone call
  say "Welcome to the King County Christmas Tree Recycling Line."

  # Setting up our options for "ask". We accept 5 digits, either spoken or entered
  # by DTMF, and time out after 10 seconds.
  zipcode_options = { :choices     => "[5 DIGITS]",
    :repeat      => 3,
    :timeout     => 10,
    :onBadChoice => lambda { say 'Invalid entry, please try again.' },
    :onTimeout   => lambda { say 'Timeout, please try again.' },
    :onChoice    => lambda { |zip| phone(zip.value) }
  }

  ask 'Enter or say your ZIP code to find a Christmas tree facility in your area.', zipcode_options
  say 'Thank you for using the King County Christmas Tree Recycling Line. Goodbye.'

elsif $currentCall.initialText =~ /^\d{5}$/
  # Text message, proper zip code
  message($currentCall.initialText)
else
  # Text message, invalid zip code
  say("Please text me a valid zip code to look up Christmas tree disposal facilities in your area.")
end

hangup
