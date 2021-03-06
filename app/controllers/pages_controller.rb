class PagesController < ApplicationController

  before_filter :authenticate_admin!, :only => :destroy
  before_filter :authenticate_user!, :except => [:show]

  before_filter :find_page, :only => [:show, :edit, :update]

  respond_to :html, :json

  def about
    @organisations_count = Organisation.count
  end

  def show
    respond_with(@page)
  end

  def index
    @pages = Page.order(:slug)
  end

  def new
    @page = Page.new
  end

  def create
    @page = Page.new(page_params)

    if @page.save
      redirect_to pages_path
    end

  end

  def update
    if @page.update_attributes(page_params)
      redirect_to :action => :show, :id => @page.slug
    end
  end

  protected

    def find_page
      @page = Page.find_by_slug!(params[:id])
    end

  private

    def page_params
      params.require(:page).permit(
        :name,
        :slug,
        :body)
    end

end