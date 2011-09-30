# == Schema Information
#
# Table name: customers
#
#  id                     :integer         not null, primary key
#  heard_about_service_id :integer
#  last_name              :string(255)
#  first_name             :string(255)
#  address_1              :string(255)
#  address_2              :string(255)
#  city                   :string(255)
#  state                  :string(255)
#  country                :string(255)
#  post_code              :string(255)
#  phone                  :string(255)
#  email                  :string(255)
#  organization           :string(255)
#  orders_count           :integer         default(0)
#  created_at             :datetime
#  updated_at             :datetime
#

class Customer < ActiveRecord::Base

  #------------------------------------------------------------------
  # relationships
  #------------------------------------------------------------------
  has_many :orders
  has_many :requests, :class_name => 'Order', :conditions => ['orders.is_approved = ?', false]
  has_many :units, :through => :orders
  has_many :master_files, :through => :units
  has_many :bibls, :through => :units
  has_many :invoices, :through => :orders
  
  has_one :billing_address
  
  # belongs_to :department
  belongs_to :heard_about_service
  
  #------------------------------------------------------------------
  # validations
  #------------------------------------------------------------------
  validates :last_name, :first_name, :address_1, :country, :city, :email, :presence => true
  validates :email, :uniqueness => true, :email => true # Email serves as a Customer object's unique identifier
  validates :last_name, :first_name, :person_name_format => true
  validates :city, :city_format => true
  validates :phone, :phone_format => true, :allow_nil => true
  
  # Validate data that could be coming in from the request form such that < and > are not
  # allowed in the text to prevent cross site scripting.
  validates :organization, :address_1, :address_2, :state, :country, :post_code, :xss => true

  # Validating presence of continued association with valid external data
  validates :heard_about_service, 
            :presence => {
              :if => 'self.heard_about_service_id', 
              :message => "association with this Customer is no longer valid because the Heard About Service object no longer exists."
            }     
  # validates :department, 
  #           :presence => {
  #             :if => 'self.department_id', 
  #             :message => "association with this Customer is no longer valid because the Department object no longer exists."
  #           }
  
  #------------------------------------------------------------------
  # callbacks
  #------------------------------------------------------------------
  before_destroy :destroyable?
  
  #------------------------------------------------------------------
  # scopes
  #------------------------------------------------------------------
  default_scope :order => [:last_name, :first_name]

  #------------------------------------------------------------------
  # public class methods
  #------------------------------------------------------------------
  # Returns a string containing a brief, general description of this
  # class/model.
  def Customer.class_description
    return 'Customer represents a person with Requests and/or Orders for digitization.'
  end
  
  #------------------------------------------------------------------
  # public instance methods
  #------------------------------------------------------------------
  # Returns a boolean value indicating whether it is safe to delete this
  # Customer from the database. Returns +false+ if this record has dependent
  # records in other tables, namely associated Order records. (We do not check
  # for a BillingAddress record, because it is considered merely an extension of
  # the Customer record; it gets destroyed when the Customer is destroyed.)
  #
  # This method is public but is also called as a +before_destroy+ callback.
  # def destroyable?  
  def destroyable?
    if not orders? and not requests?
      return false
    else
      return true
    end
  end
  
  # Returns a boolean value indicating whether this Customer has
  # associated Order records.
  def orders?
    return false unless orders.any?
  end
   
  # Returns a boolean value indicating whether this Customer has
  # associated Request (unapproved Order) records.
  def requests?
   return false unless requests.any?
  end

  def full_name
    [first_name, last_name].join(' ')
  end

  alias_attribute :date_of_first_order, :created_at
end