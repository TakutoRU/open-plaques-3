# This class represents a role ascribed to a person. These can be professions (eg 'doctor'), occupations ('artist'), or activities ('inventor').
#
# === Attributes
# * +name+ - The name of the role.
# * +role_type+ - The classification of the role (see self.types for choice)
# * +wikipedia_stub+ - url of a relevant Wikipedia page
# * +index+ - letter indexed on
# * +abbreviation+ - acronym etc. when a role is commonly abbreviated, especially awards, e.g. Victoria Cross == VC
# * +prefix+ - word(s) to display as part of a title in a name
# * +suffix+ - word(s) to display as part of letters after a name
#
# === Associations
# * +personal_roles+ - how people are connected to this role
#
# === Indirect Associations
# * +people+ - The people who have been ascribed this role.
class Role < ActiveRecord::Base

  before_validation :make_slug_not_war
  before_save :update_index, :filter_name
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug

  has_many :personal_roles, -> { order('started_at') }
  has_many :people, -> { order('name') }, :through => :personal_roles

  scope :by_popularity, -> { order("personal_roles_count DESC nulls last") }
  scope :alphabetically, -> { order("name ASC nulls last") }
  scope :name_starts_with, lambda {|term| where(["lower(name) LIKE ?", term.downcase + "%"]) }
  scope :name_contains, lambda {|term| where(["lower(name) LIKE ?", "%" + term.downcase + "%"]) }

  include ApplicationHelper

  def related_roles
    Role.where(['lower(name) != ? and (lower(name) LIKE ? or lower(name) LIKE ? or lower(name) LIKE ? )', name.downcase, 
    "#{name.downcase} %", "% #{name.downcase} %", "% #{name.downcase}"])
  end
  
  def self.types
    ["person", "man", "woman", "animal", "thing", "group", "place", "relationship", "parent", "spouse", "child", "title", "letters", "military medal", "clergy"]
  end

  def person?
    return false if animal? or thing? or group? or place?
	  return true
  end

  def animal?
    return true if "animal" == role_type
	  return false
  end

  def thing?
    return true if "thing" == role_type
    return false
  end

  def group?
    return true if "group" == role_type
    return false
  end

  def place?
    return true if "place" == role_type
    return false
  end
  
  def type
	  return "person" if person?
	  return "animal" if animal?
	  return "thing" if thing?
	  return "group" if group?
	  return "place" if place?
	  return "?"
  end
  
  # work it out from the name unless override value stored in the db
  def wikipedia_stub
    self[:wikipedia_stub] ? self[:wikipedia_stub] : self.name.capitalize.strip.gsub(/ /,"_")
  end
  
  def dbpedia_url
    "http://dbpedia.org/resource/" + wikipedia_stub
  end
  
  def wikipedia_url
    "https://en.wikipedia.org/wiki/" + wikipedia_stub
  end
  
  def relationship?
    return true if "relationship" == role_type
    return true if "parent" == role_type
    return true if "spouse" == role_type
    return true if "child" == role_type
    return true if "group" == role_type
    false
  end
  
  def used_as_a_prefix?
    return true if "title" == role_type
    false
  end
  
  def military_medal?
    return true if "military medal" == role_type
    false
  end

  def used_as_a_suffix?
    return true if !suffix.blank?
    return true if "letters" == role_type
    return true if military_medal?
    false
  end

  def letters
    return suffix if !suffix.blank?
    return abbreviation if used_as_a_suffix?
    ""
  end
  
  def abbreviated?
    return false if abbreviation.blank?
    true
  end
  
  def confers_honourific_title?
    return true if "Baronet" == name
    return true if "Baroness" == name
    return true if "Knight Bachelor" == name
    return true if "Knight of the Order of the Garter" == name
    return true if "Knight of the Order of the Thistle" == name
    return true if "Knight Commander of the Order of the Bath" == name
    return true if "Knight Grand Cross of the Order of the Bath" == name
    return true if "Knight Commander of the Order of St Michael and St George" == name
    return true if "Knight Grand Cross of the Order of St Michael and St George" == name
    return true if "Knight Commander of the Royal Victorian Order" == name
    return true if "Knight Grand Cross of the Royal Victorian Order" == name
    return true if "Knight Commander of the Order of the British Empire" == name
    return true if "Knight Grand Cross of the Order of the British Empire" == name
    return true if "Lady" == name
    false
  end

  def female?
    return true if "woman" == role_type
    return true if "wife" == name
    return true if "sister" == name
    return true if "half-sister" == name
    return true if "daughter" == name
    return true if "mother" == name
    return true if "Baroness" == name
    return true if "Dame" == name
    return true if "Dame Commander of the Most Excellent Order of the British Empire" == name
    return true if "Dame Commander of the Royal Victorian Order" == name
    return true if "Empress" == name
    return true if "Empress of India" == name
    return true if "Lady" == name
    return true if "Queen" == name
    return true if "Woman Police Constable" == name
    return true if name.start_with?("Viscountess")
    false
  end

  def male?
    !self.female?
  end
  
  def full_name
    return abbreviation + " - " + name if abbreviated?
    name
  end

  def display_name
    abbreviated? ? abbreviation : name
  end
  
  def uri
    "http://openplaques.org" + Rails.application.routes.url_helpers.role_path(self.slug, :format => :json)
  end

  def to_s
    name
  end

  def as_json(options={})
    options = {
      :only => [:name, :personal_roles_count, :role_type, :abbreviation],
      :methods => [:type, :full_name, :male?, :relationship?, :confers_honourific_title?]
    } if !options || !options[:only]
    super options
  end

  private

    def update_index
      self.index = self.name[0,1].downcase
    end

    def filter_name
      self.name = self.name.gsub(/\.?\??/, "").strip
    end

end
