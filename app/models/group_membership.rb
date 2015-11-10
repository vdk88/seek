class GroupMembership < ActiveRecord::Base
  belongs_to :person
  belongs_to :work_group
  has_one :project, :through=>:work_group

  has_many :group_memberships_project_roles, :dependent => :destroy
  has_many :project_roles, :through => :group_memberships_project_roles

  after_save :remember_previous_person
  after_commit :queue_update_auth_table

  validates :work_group,:presence => {:message=>"A workgroup is required"}

  def has_left=(yes = false)
    self.time_left_at = yes ? Time.now : nil
  end

  def has_left
    self.time_left_at && self.time_left_at.past?
  end

  def remember_previous_person
    @previous_person_id = person_id_was
  end

  def queue_update_auth_table
    people = [Person.find_by_id(person_id)]
    people << Person.find_by_id(@previous_person_id) unless @previous_person_id.blank?

    AuthLookupUpdateJob.new.add_items_to_queue people.compact
  end

end
