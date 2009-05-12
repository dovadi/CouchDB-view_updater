#!/usr/bin/ruby

require "YAML"

###################
# CONF            #
###################

# The smallest amount of changed documents before the views are updated
MIN_NUM_OF_CHANGED_DOCS = 10

# URL to the DB on the CouchDB server
URL = "http://localhost:5984"

# Set the minimum pause between calls to the database
PAUSE = 1 # seconds


# Views of databases are defined in couchdb.yml
VIEWS = YAML.load(File.read("#{File.dirname(__FILE__)}/couchdb.yml"))

###################
# RUNTIME         #
###################

run = true
number_of_changed_docs = {}

threads = []

# Updates the views
threads << Thread.new do

  while run do

    number_of_changed_docs.each_pair do |db_name, number_of_docs|
      if number_of_docs >= MIN_NUM_OF_CHANGED_DOCS
        
        # Reset the value
        number_of_changed_docs[db_name] = 0
        
        # If there are views in the database, get them
        if VIEWS[db_name]
          VIEWS[db_name].each do |design, views|
            views.each do |view|
              `curl #{URL}/#{db_name}/_design/#{design}/_view/#{view}?limit=0`
            end
          end
        end

      end
    end

    # Pause before starting over again
    sleep PAUSE
    
  end
  
end

# Receives the update notification from CouchDB
threads << Thread.new do

  while run do

    STDERR << "Waiting for input\n"
    update_call = gets
    
    # When CouchDB exits the script gets called with
    # a never ending series of nil
    if update_call == nil
      run = false
    else
      # Get the database name out of the call data
      # The data looks somethind like this:
      # {"type":"updated","db":"DB_NAME"}\n
      update_call =~ /\"db\":\"(\w+)\"/
      database_name = $1
      
      # Set to 0 if it hasn't been initialized before
      number_of_changed_docs[$1] ||= 0
      
      # Add one pending changed document to the list of documents
      # in the DB
      number_of_changed_docs[$1] += 1
      
    end
    
  end

end

# Good bye
threads.each {|thr| thr.join}
