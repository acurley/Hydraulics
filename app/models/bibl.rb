# == Schema Information
#
# Table name: bibls
#
#  id                        :integer         not null, primary key
#  availability_policy_id    :integer
#  parent_bibl_id            :integer         default(0), not null
#  date_external_update      :datetime
#  description               :string(255)
#  is_approved               :boolean         default(FALSE), not null
#  is_collection             :boolean         default(FALSE), not null
#  is_in_catalog             :boolean         default(FALSE), not null
#  is_manuscript             :boolean         default(FALSE), not null
#  is_personal_item          :boolean         default(FALSE), not null
#  automation_messages_count :integer         default(0)
#  orders_count              :integer         default(0)
#  units_count               :integer         default(0)
#  barcode                   :string(255)
#  call_number               :string(255)
#  catalog_id                :string(255)
#  citation                  :text
#  copy                      :integer
#  creator_name              :string(255)
#  creator_name_type         :string(255)
#  genre                     :string(255)
#  issue                     :string(255)
#  location                  :string(255)
#  resource_type             :string(255)
#  series_title              :string(255)
#  title                     :string(255)
#  title_control             :string(255)
#  volume                    :string(255)
#  year                      :string(255)
#  year_type                 :string(255)
#  dc                        :text
#  desc_metadata             :text
#  discoverability           :boolean         default(TRUE), not null
#  exemplar                  :string(255)
#  pid                       :string(255)
#  rels_ext                  :text
#  rels_int                  :text
#  solr                      :text(16777215)
#  date_ingested_into_dl     :datetime
#  created_at                :datetime
#  updated_at                :datetime
#

class Bibl < ActiveRecord::Base
   
  #------------------------------------------------------------------
  # validations
  #------------------------------------------------------------------
  # validates_datetime :date_external_update

  #------------------------------------------------------------------
  # relationships
  #------------------------------------------------------------------
  has_many :units
  has_many :orders, :through => :units
  has_many :master_files, :through => :units
  has_many :customers, :through => :orders
  has_many :components
  has_many :ead_refs
  has_many :automation_messages

  #------------------------------------------------------------------
  # scopes
  #------------------------------------------------------------------  
  scope :approved, where(:is_approved => true)
  scope :in_dl, where("date_ingested_into_dl is not null").order("date_ingested_into_dl DESC")
  scope :not_approved, where(:is_approved => false)
  scope :has_exemplars, where("exemplar is NOT NULL")
  scope :need_exemplars, where("exemplar is NULL")
  
  #------------------------------------------------------------------
  # callbacks
  #------------------------------------------------------------------
  before_save do    
    # boolean fields cannot be NULL at database level
    self.is_approved = 0 if self.is_approved.nil?
    self.is_collection = 0 if self.is_collection.nil?
    self.is_in_catalog = 0 if self.is_in_catalog.nil?
    self.is_manuscript = 0 if self.is_manuscript.nil?
    self.is_personal_item = 0 if self.is_personal_item.nil?
    self.discoverability = 1 if self.discoverability.nil? # For Bibl objects, the default value is 1 (i.e. is discoverable)
    
    # get pid
    if self.pid.blank?
      begin
        self.pid = AssignPids.get_pid
      rescue Exception => e
        #ErrorMailer.deliver_notify_pid_failure(e) unless @skip_pid_notification
      end
    end

    # Moved from after_initialize in order to make compliant with 2.3.8
    if self.is_in_catalog.nil?
      # set default value
      if self.is_personal_item?
        self.is_in_catalog = false
      else
        # held by Library; default to assuming it's in Library catalog
        self.is_in_catalog = true
      end
    end
  end
  
  before_destroy :destroyable?
   
  #------------------------------------------------------------------
  # public class methods
  #------------------------------------------------------------------
 
  #------------------------------------------------------------------
  # public instance methods
  #------------------------------------------------------------------
  # Returns an array of Bibl objects that are the parent, grandparent, etc... of the 
  # Bibl object upon which this method is invoked.
  def ancestors
    parent_bibls = Array.new
    if parent_bibl_id != 0
      begin
        bibl = parent_bibl
        parent_bibls << bibl
        parent_bibls << bibl.ancestors unless bibl.ancestors.nil?
        return parent_bibls.flatten
      rescue ActiveRecord::RecordNotFound
        return parent_bibls.flatten
      end
    end
  end
  
  # Returns the array of Bibl objects for which this Bibl is parent.
  def child_bibls
    begin 
      return Bibl.find(:all, :conditions => "parent_bibl_id = #{id}")
    rescue ActiveRecord::RecordNotFound
      return Array.new
    end
  end
  
  def components?
    return false unless components.any?  
  end
  
  def dl_master_files
    return master_files.where("date_dl_deliverables_ready is NOT NULL")
  end
    
  # Returns a boolean value indicating whether it is safe to delete this record
  # from the database. Returns +false+ if this record has dependent records in
  # other tables, namely associated Unit, Component, or EadRef records.
  #
  # This method is public but is also called as a +before_destroy+ callback.
  def destroyable?
    if ead_refs? || components? || units?
      return false
    else
      return true
    end      
  end
  
  def ead_refs?
    return false unless ead_refs.any?  
  end

  def in_dl?
    return self.date_ingested_into_dl?
  end
      
  def master_file_filenames
    return master_files.map(&:filename) 
  end
  
  def parent_bibl
    begin
      return Bibl.find(parent_bibl_id)
    rescue ActiveRecord::RecordNotFound
      return nil
    end
  end
 
  def units?
    return false unless units.any?  
  end
  
  #------------------------------------------------------------------
  # aliases
  #------------------------------------------------------------------
  alias :parent :parent_bibl
end