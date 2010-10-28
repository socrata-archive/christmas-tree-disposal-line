
require 'net/http'
require 'uri'
require 'json'

# Look up facilities given a zip code and type
def lookup_facilities(zip_code)
  log "Looking for facilities in zip code #{zip_code}..."
  query = {
    "originalViewId" => "zqwi-c5q3",
    "name" => "What do I do with",
    "query" => {
        "filterCondition" => {
          "type" => "operator",
          "value" => "AND",
          "children" => [ {
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

  request = Net::HTTP::Post.new("/api/views/INLINE/rows.json?method=index")
  request.body = query.to_json
  request.content_type = "application/json"
  response = Net::HTTP.start("www.datakc.org", 80){ |http| http.request(request) }

  if response.code != "200"
    log "Error code: #{response.code}"
    log "Body: #{response.body}"
    say "An error has occurred. I\'m very sorry. Please don\'t hate me."
  else
    results = JSON::parse(response.body)["data"]
    if results.size <= 0
      say "Sorry, I did not find any results for your search."
    else
      say "I found #{results.size} matches. I'll read them to you now."
      say results.map{|r| "#{r[9]} at #{r[10]}. Their hours are #{r[15]}." }.join(" or, ")
    end
  end

  log(response.inspect)
end

answer
sleep(2)
say "Welcome to the King County Christmas Tree Recycling Line."

zipcode_options = { :choices     => "[5 DIGITS]",
                    :repeat      => 3,
                    :timeout     => 7,
                    :onBadChoice => lambda { say 'Invalid entry, please try again.' },
                    :onTimeout   => lambda { say 'Timeout, please try again.' },
                    :onChoice    => lambda { |zip| lookup_facilities(zip.value) }
                  }

ask 'Enter or say your ZIP code to find a Christmas tree facility in your area.', zipcode_options
say 'Thank you for using the King County Christmas Tree Recycling Line. Goodbye.'

hangup
