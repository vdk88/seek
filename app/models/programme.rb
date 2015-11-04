class Programme < ActiveRecord::Base
  attr_accessible :avatar_id, :description, :first_letter, :title, :uuid, :web_page, :project_ids, :funding_details, :administrator_ids, :activation_rejection_reason

  attr_accessor :administrator_ids

  searchable(auto_index: false) do
    text :funding_details
    text :institutions do
      institutions.compact.map(&:title)
    end
  end if Seek::Config.solr_enabled
  acts_as_yellow_pages

  # associations
  has_many :projects, dependent: :nullify
  has_many :admin_defined_role_programmes
  accepts_nested_attributes_for :projects

  # validations
  validates :title, uniqueness: true
  after_save :handle_administrator_ids, if: '@administrator_ids'
  before_create :activate_on_create

  scope :default_order, order('title')
  scope :activated, where(is_activated: true)
  scope :rejected, where("is_activated = ? AND activation_rejection_reason IS NOT NULL",false)

  def people
    projects.collect(&:people).flatten.uniq
  end

  def institutions
    projects.collect(&:institutions).flatten.uniq
  end

  def can_be_edited_by?(user)
    can_edit?(user)
  end

  def can_edit?(user = User.current_user)
    new_record? || can_manage?(user)
  end

  def can_manage?(user = User.current_user)
    user && (user.is_admin? || user.person.is_programme_administrator?(self))
  end

  def can_delete?(user = User.current_user)
    user && user.is_admin?
  end

  def rejected?
    !(self.activation_rejection_reason.nil? || is_activated?)
  end

  # callback, activates if current user is an admin or nil, otherwise it needs activating
  def activate
    if can_activate?
      self.update_attribute(:is_activated,true)
      self.update_attribute(:activation_rejection_reason,nil)
    end
  end

  def can_activate?(user = User.current_user)
    user && user.is_admin? && !is_activated?
  end

  def self.can_create?
    return false unless Seek::Config.programmes_enabled
    (User.admin_logged_in?) || (User.logged_in_and_registered? && Seek::Config.allow_user_programme_creation)
  end

  def administrators
    Seek::Roles::ProgrammeRelatedRoles.instance.people_with_programme_and_role(self, 'programme_administrator')
  end

  private

  # set the administrators, assigned from the params to :adminstrator_ids
  def handle_administrator_ids
    new_administrators = Person.find(administrator_ids)
    to_add = new_administrators - administrators
    to_remove = administrators - new_administrators
    to_add.each do |person|
      person.is_programme_administrator = true, self
      disable_authorization_checks { person.save! }
    end
    to_remove.each do |person|
      person.is_programme_administrator = false, self
      disable_authorization_checks { person.save! }
    end
  end

  # callback, activates if current user is an admin or nil, otherwise it needs activating
  def activate_on_create
    if User.current_user && !User.current_user.is_admin?
      self.is_activated = false
    else
      self.is_activated = true
    end
    true
  end


end