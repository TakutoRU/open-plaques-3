class AreaPlaquesController < ApplicationController

  before_filter :find, :only => [:show]
  respond_to :html, :xml, :json

  def show
    @display = 'all'
    if (params[:id] && params[:id]=='unphotographed')
      if request.format == 'json' or request.format == 'xml'
        @plaques = @area.plaques.unphotographed
      else
        @plaques = @area.plaques.unphotographed.paginate(:page => params[:page], :per_page => 50)
      end
      @display = 'unphotographed'
    elsif (params[:id] && params[:id]=='current')
      if request.format == 'json' or request.format == 'xml'
        @plaques = @area.plaques.current
      else
        @plaques = @area.plaques.current.paginate(:page => params[:page], :per_page => 50)
      end
    elsif (params[:id] && params[:id]=='ungeolocated')
      if request.format == 'json' or request.format == 'xml'
        @plaques = @area.plaques.ungeolocated
      else
        @plaques = @area.plaques.ungeolocated.paginate(:page => params[:page], :per_page => 50)
      end
      @display = 'ungeolocated'
    else
      if request.format == 'json' or request.format == 'xml'
        @plaques = @area.plaques
      else
        @plaques = @area.plaques.paginate(:page => params[:page], :per_page => 50)
      end
    end
    @area.find_centre if !@area.geolocated?
    respond_with @plaques do |format|
      format.html
      format.xml
      format.json { render :json => @plaques }
      format.geojson { render :geojson => @plaques.geolocated, :parent => @area }
    end
  end

  protected

    def find
      @country = Country.find_by_alpha2!(params[:country_id])
      @area = @country.areas.find_by_slug!(params[:area_id])
    end

end
