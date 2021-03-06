require 'open-uri'
require 'net/http'
require 'uri'
require 'rexml/document'

module PlaquesHelper

  def marked_text(text, term)
    text.to_s.gsub(/(#{term})/i, '<mark>\1</mark>').html_safe
  end

  def search_snippet(text, search_term)
    regex = /#{search_term}/i
    if text =~ regex
      text = " " + text + " "  #HACK: This is so there's a space before the first word.
      indexes = []
      first_index = text.index(regex)
      indexes << first_index
      second_index = text.index(regex, (first_index + search_term.length + 50))
      indexes << second_index if second_index
      snippet = ""
      indexes.each do |i|
        i = i - 80
        i = 0 if i < 0
        s = text[i, 160]
        first_space = (s.index(/\s/) + 1)
        last_space = (s.rindex(/\s/) - 1)
        snippet += "..." if i > 0
        snippet += (s[first_space..last_space])
        snippet += "..." if last_space + 2 < text.length
      end
      snippet
    else
      return text
    end
  end

  def kml(plaque, xml)
    if plaque.geolocated?
      xml.Placemark do
        xml.name(plaque.title)
        xml.description do
          xml.cdata!(("<p>" + plaque.inscription + "</p> <p><a href=\"" + plaque_url(plaque) + "\">" + thumbnail_img(plaque) + "</a></p>").html_safe)
        end
        if plaque.latitude && plaque.longitude
          xml.Point do
            xml.coordinates plaque.longitude.to_s + ',' + plaque.latitude.to_s + ",0"
          end
        end
        if plaque.colour && plaque.colour.slug =~ /(blue|black|yellow|red|white|green)/
          xml.styleUrl "#plaque-" + plaque.colour.slug
        else
          xml.styleUrl "#plaque-blue"
        end
      end
    end
  end

  # pass null to search all machinetagged photos on Flickr
  def find_photo_by_machinetag(plaque, flickr_user_id)
#    key = FLICKR_KEY # "86c115028094a06ed5cd19cfe72e8f8b"
    key = "86c115028094a06ed5cd19cfe72e8f8b"
    content_type = "1" # Photos only
    machine_tag_key = "openplaques:id=".to_s
    repeat = 20 # 100 per page, we will check the 2000 most recently created Flickr images
    if (plaque)
      machine_tag_key += plaque.id.to_s
      repeat = 1 # 100 per page, so I hope that one plaque has fewer than 100 Flickr images
    end

    flickr_url = "https://api.flickr.com/services/rest/"
    method = "flickr.photos.search"
    license = "1,2,3,4,5,6,7,8,9,10"

    repeat.times do |page|

      url = flickr_url + "?api_key=" + key + "&method=" + method + "&page=" + page.to_s + "&license=" + license + "&content_type=" + content_type + "&machine_tags=" + machine_tag_key +  "&extras=date_taken,owner_name,license,geo,machine_tags"

      if (flickr_user_id)
        url += "&user_id=" + flickr_user_id
      end
      puts "Flickr: " + url

      new_photos_count = 0
      response = open(url)
      doc = REXML::Document.new(response.read)
      doc.elements.each('//rsp/photos/photo') do |photo|
        print "."
        $stdout.flush

        @photo = nil

        file_url = "http://farm" + photo.attributes["farm"] + ".staticflickr.com/" + photo.attributes["server"] + "/" + photo.attributes["id"] + "_" + photo.attributes["secret"] + "_z.jpg"
        photo_url = "http://www.flickr.com/photos/" + photo.attributes["owner"] + "/" + photo.attributes["id"] + "/"

        @photo = Photo.find_by_url(photo_url)
        if @photo
          # we've already got that one
        else
          plaque_id = photo.attributes["machine_tags"][/openplaques\:id\=(\d+)/, 1]
          puts "Flickr: photo of plaque " + plaque_id.to_s + " '" + photo.attributes["title"] + "'"
          @plaque = Plaque.find_by_id(plaque_id)
          if @plaque
            @photo = Photo.new
            @photo.plaque = @plaque
            @photo.file_url = file_url
            @photo.url = photo_url
            @photo.taken_at = photo.attributes["datetaken"]
            @photo.photographer_url = photo_url = "http://www.flickr.com/photos/" + photo.attributes["owner"] + "/"
            @photo.photographer = photo.attributes["ownername"]
            @photo.licence = Licence.find_by_flickr_licence_id(photo.attributes["license"])
            if photo.attributes["latitude"] != "0"
              @photo.latitude = photo.attributes["latitude"]
              @photo.longitude = photo.attributes["longitude"]
            end
            if @photo.save
              new_photos_count += 1
              puts "New photo found and saved"
            else
#            puts "Error saving photo" + @photo.errors.each_full{|msg| puts msg }
            end
          else
            puts "Photo's machine tag doesn't match a plaque."
          end
        end
      end
    end
  end

    # pass null to search all photos on Flickr
    def crawl_flickr(group_id='74191472@N00')
    
      key = "86c115028094a06ed5cd19cfe72e8f8b" # FLICKR_KEY
      content_type = "1" # Photos only
      flickr_url = "https://api.flickr.com/services/rest/"
      method = "flickr.photos.search"
      jez = User.find(2)
      black = Colour.find_by_name('black')
      english = Language.find_by_name('English')
      new_photos_count = 0
            
      19.times do |page|
        puts page.to_s
        url = flickr_url + "?api_key=" + key + "&method=" + method + "&page=" + page.to_s + "&per_page=5&content_type=" + content_type + "&extras=date_taken,owner_name,license,geo,description"
        if group_id
          url += "&group_id=" + group_id
        end
        response = open(url)
        doc = REXML::Document.new(response.read)
        doc.elements.each('//rsp/photos/photo') do |photo|
          print "."
          $stdout.flush
          @photo = nil
          file_url = "http://farm" + photo.attributes["farm"] + ".staticflickr.com/" + photo.attributes["server"] + "/" + photo.attributes["id"] + "_" + photo.attributes["secret"] + "_z.jpg"
          photo_url = "http://www.flickr.com/photos/" + photo.attributes["owner"] + "/" + photo.attributes["id"] + "/"
          @photo = Photo.find_by_url(photo_url)
          inscription_is_stub = true
          if photo.attributes["title"]!=nil
            subject = photo.attributes["title"].split(",")[0].split("()")[0].rstrip.lstrip + "."
            inscription = subject
          end
          if photo.elements["description"].text != nil && photo.elements["description"].text.length > 50
            inscription << " " + photo.elements["description"].text
          end
          if @photo
            puts "photo already exists in Open Plaques"
          else
            # Plaque find by location and name if already exists.....
#            32.76696, -94.348526
#            32.766955, -94.348472
            # Plaque.find_or_create_by_???
            @plaque = Plaque.new(:inscription => inscription, :user => jez, :inscription_is_stub => inscription_is_stub, :colour => black, :language => english)
            @plaque.location = Location.new(:name => 'somewhere in Texas')
            # the Flickr woeids appear to be at town level, so can only create an area from them
            woeid = photo.attributes["woeid"]
            if woeid != nil
              area = Area.find_or_create_by_woeid(woeid)
              if area != nil
                @plaque.location.area = area
              else
                puts "error: provided woeid " + woeid + " but got no area back"
              end
            end
            if @plaque
              @photo = Photo.new
              @photo.plaque = @plaque
              @photo.file_url = file_url
              @photo.url = photo_url
              @photo.taken_at = photo.attributes["datetaken"]
              @photo.photographer_url = photo_url = "http://www.flickr.com/photos/" + photo.attributes["owner"] + "/"
              @photo.photographer = photo.attributes["ownername"]
              @photo.licence = Licence.find_by_flickr_licence_id(photo.attributes["license"])
              if photo.attributes["latitude"] != "0" && photo.attributes["longitude"] != "0" && !@plaque.geolocated?
                @plaque.latitude = photo.attributes["latitude"]
                @plaque.longitude = photo.attributes["longitude"]
              end
              if @plaque.save
                puts "New plaque and photo added"
              else
                puts "Error adding plaque " + @plaque.errors.full_messages.to_s
              end
              if @photo.save
                puts "New photo found and saved"
              else
                puts "Error saving photo" + @photo.errors.each_full{|msg| puts msg }
              end
            end
          end
        end
      end
    end

  def poi(plaque)
    if plaque.geolocated? && plaque.people.size() > 0
    plaque.longitude.to_s + ', ' + plaque.latitude.to_s + ", \"" + plaque.people.collect(&:name).to_sentence + "\"" + "\r\n"
    end
  end

  def personal_connection_path(pc)
    url_for(:controller => "PersonalConnections", :action => :show, :id => pc.id, :plaque_id => pc.plaque_id)
  end

  def personal_connections_path(plaque)
    url_for(:controller => "PersonalConnections", :action => :index, :plaque_id => plaque.id)
  end

  def edit_personal_connection_path(pc)
    url_for(:controller => "PersonalConnections", :action => :edit, :id => pc.id, :plaque_id => pc.plaque_id)
  end

  def new_personal_connection_path(plaque)
    url_for(:controller => "PersonalConnections", :action => :new, :plaque_id => plaque.id)
  end

  def erected_date(plaque)
    if plaque.erected_at?
      if plaque.erected_at.day == 1 && plaque.erected_at.month == 1
        "in ".html_safe + plaque.erected_at.year.to_s
      else
        "on ".html_safe + plaque.erected_at.strftime('%d %B %Y')
      end
    else
      "sometime in the past"
    end
  end

  def erected_information(plaque)
    info = "".html_safe
    if plaque.erected_at? || plaque.organisations.size > 0
      info += "by ".html_safe if plaque.organisations.size > 0
      org_list = []
      plaque.organisations.each do |organisation|
        org_list << link_to(h(organisation.name), organisation)
      end
      info += org_list.to_sentence.html_safe
      if plaque.erected_at?
        info += " ".html_safe
        if plaque.erected_at.day == 1 && plaque.erected_at.month == 1
          info += "in ".html_safe
        else
          info += "on ".html_safe + plaque.erected_at.strftime('%d %B') + " "
        end
        info += plaque.erected_at.year.to_s
      end
      return content_tag("p", info)
    else
      return content_tag("p", "by ".html_safe + content_tag("span", "unknown".html_safe, :class => :unknown))
    end
  end
  
  def geolocation_if_known(plaque)
    if plaque.geolocated?
      geo_microformat(plaque)
    else
      unknown()
    end
  end

  def map_icon_if_known(plaque)
    if plaque.geolocated?
      geo_map_icon_link(plaque)
    else
      ""
    end
  end

  def google_map_if_known(content, plaque)
    if plaque.geolocated?
      link_to_google_map(content, plaque.latitude, plaque.longitude)
    else
      unknown()
    end
  end

  def google_streetview_if_known(content, plaque)
    if plaque.geolocated?
      link_to_google_streetview(content, plaque.latitude, plaque.longitude)
    else
      unknown()
    end
  end

  def google_earth_if_known(content, plaque)
    if plaque.geolocated?
      link_to_google_earth(content, plaque.id)
    else
      unknown()
    end
  end

  # Generates a link to Open Street Map using latitude ang longitude.
  def link_to_osm(content, latitude, longitude, marker = true)
   link_to(content, "http://www.openstreetmap.org/?lat=" + latitude.to_s + "&amp;lon=" + longitude.to_s + "&amp;zoom=17&amp;mlat=" + latitude.to_s + "&amp;mlon=" + longitude.to_s)
  end

  # Generates a link to Google Maps using latitude ang longitude.
  def link_to_google_map(content, latitude, longitude)
   link_to(content, "http://maps.google.co.uk?q=" + latitude.to_s + "," + longitude.to_s)
  end

  # Generates a link to Google Street View using latitude ang longitude.
  def link_to_google_streetview(content, latitude, longitude)
   link_to(content, "http://maps.google.co.uk/?q=" + latitude.to_s + "," + longitude.to_s + "&layer=c&cbll=" + latitude.to_s + "," + longitude.to_s + "&cbp=12,0,,0,5")
  end

  # Generates a link to Google Earth using id for kml.
  def link_to_google_earth(content, id)
   link_to(content, "http://maps.google.co.uk?t=f&q=http://openplaques.org/plaques/" + id.to_s + ".kml")
  end

  def osm_iframe(latitude, longitude, bboffset = 0.001, height = 200, width = 300, marker = true)
    bb = (longitude - bboffset).to_s + "," + (latitude - bboffset).to_s + "," + (longitude + bboffset).to_s + "," + (latitude + bboffset).to_s

    osm_embed_src = "http://www.openstreetmap.org/export/embed.html?bbox=" + bb + "&amp;marker=" + latitude.to_s + "," + longitude.to_s + "&amp;layer=mapnik"
    return content_tag("iframe","",{:height => height, :width => width, :scrolling => "no", :frameborder => "no", :marginheight => "0", :marginwidth => "0", :src => osm_embed_src, :class => "osm"})
  end

  def geo_microformat(plaque, container = "span")
    if !plaque.geolocated?
      return ""
    end
    @lat = content_tag("span", plaque.latitude, {:class => "latitude", :property => "geo:lat", :about => "#plaque_location"})
    @lon = content_tag("span", plaque.longitude, {:class => "longitude", :property => "geo:long", :about => "#plaque_location"})
    content_tag(container, link_to_osm("[osm]", plaque.latitude, plaque.longitude), {:class => "geo", :typeof => "geo:Point", :about => "#plaque_location"})
  end

  def geo_map_icon_link(plaque)
    if !plaque.geolocated?
    return "";
    end
    @alt = plaque.latitude.to_s + ", " + plaque.longitude.to_s
    @image = image_tag("map_icon.png", {:alt => @alt})
    link_to_osm(@image, plaque.latitude, plaque.longitude )
  end

  def plaque_icon(plaque)
    if plaque.colour && plaque.colour.slug =~ /(blue|black|yellow|red|white|green)/
      image_tag("icon-" + plaque.colour.slug + ".png", :size => "16x16")
    else
      image_tag("icon-blue.png", :size => "16x16")
    end
  end

  def new_linked_inscription(plaque)
    inscription = plaque.inscription.gsub(/\r/," ").gsub(/\n/," ").strip.gsub("  "," ")
    people = plaque.people
    if people
      reduced_inscription = inscription
      people.each_with_index do |person, person_index|
        matched = false
        search_for = ""
        person.names.each_with_index do |name, index|
          if (!matched)
            search_for = name
#            puts '*** search ' + reduced_inscription + " for " + search_for
            matched = true if reduced_inscription.index(search_for) != nil
#            puts '*** found ' + search_for + " [" + index.to_s + "]" if matched
          end
        end
        reduced_inscription = reduced_inscription.gsub(search_for, "") if matched
        inscription = inscription.gsub(search_for, link_to(search_for, person_path(person))).html_safe if matched
      end
    end
    inscription += " [full inscription unknown]" if plaque.inscription_is_stub
    inscription += " [has not been erected yet]" if !plaque.erected? 
    return inscription
  end

  # given a set of plaques, or a thing that has plaques (like an organisation) tell me what the mean point is
  def find_mean(things)
    begin
      @centre = Point.new
      @centre.latitude = 51.475 # Greenwich Meridian
      @centre.longitude = 0
      begin
        @lat = 0
        @lon = 0
        @count = 0
        things.each do |thing|
          if thing.geolocated?
            @lat += thing.latitude
            @lon += thing.longitude
            @count = @count + 1
          end
        end
        @centre.latitude = @lat / @count
        @centre.longitude = @lon / @count
        return @centre
      rescue
        # oh, maybe it's a thing that has plaques
        return find_mean(thing.plaques)
      end
    rescue
      # something went wrong, failing gracefully
      return @centre
    end
  end

  def geolocation_from(url)
    # https://www.google.com/maps/place/ulitsa+Goncharova,+48,+Ulyanovsk,+Ulyanovskaya+oblast',+Russia,+432011/@54.319775,48.39987,17z/data=!3m1!4b1!4m2!3m1!1s0x415d37692250ea21:0xeab69349916c0171
    # https://www.google.com/maps/@37.0625,-95.677068,4z
    p = Point.new
    r = /@([-\d.\d]*),([-\d.\d]*)/
    if (url[r])
      p.latitude = url[r,1]
      p.longitude = url[r,2]
      return p
    end
    # or OSM
    # https://www.openstreetmap.org/#map=17/57.14772/-2.10572
    r = /map=[\d]*\/([-\d.\d]*)\/([-\d.\d]*)/
    if (url[r])
      p.latitude = url[r,1]
      p.longitude = url[r,2]
      return p
    end
    # or Geohack
    # https://tools.wmflabs.org/wiwosm/osm-on-ol/commons-on-osm.php?zoom=16&lat=43.725688888889&lon=7.2722138888889
    r = /&lat=([-\d.\d]*)&lon=([-\d.\d]*)/
    if (url[r])
      p.latitude = url[r,1]
      p.longitude = url[r,2]
      return p
    end
    p
  end

  class Point
    attr_accessor :precision
    attr_accessor :latitude
    attr_accessor :longitude
    attr_accessor :zoom
  end

end
