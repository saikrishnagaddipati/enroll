class EmployerProfile
  include Mongoid::Document
  include Mongoid::Timestamps
  include AASM

  embedded_in :organization

  ENTITY_KINDS = ["c_corporation", "s_corporation", "partnership", "tax_exempt_organization"]

  field :entity_kind, type: String
  field :sic_code, type: String

  # Broker agency representing ER
  field :broker_agency_profile_id, type: BSON::ObjectId

  # Broker writing_agent credited for enrollment and transmitted on 834
  field :writing_agent_id, type: BSON::ObjectId

  field :aasm_state, type: String
  field :aasm_message, type: String

  field :is_active, type: Boolean, default: true

  delegate :hbx_id, to: :organization, allow_nil: true
  delegate :legal_name, :legal_name=, to: :organization, allow_nil: true
  delegate :dba, :dba=, to: :organization, allow_nil: true
  delegate :fein, :fein=, to: :organization, allow_nil: true
  delegate :is_active, :is_active=, to: :organization, allow_nil: false
  delegate :updated_by, :updated_by=, to: :organization, allow_nil: false

  embeds_many :premium_statements

  embeds_many :employee_families,
    class_name: "EmployerCensus::EmployeeFamily",
    cascade_callbacks: true,
    validate: true
  accepts_nested_attributes_for :employee_families, reject_if: :all_blank, allow_destroy: true

  embeds_many :plan_years, cascade_callbacks: true, validate: true
  accepts_nested_attributes_for :plan_years, reject_if: :all_blank, allow_destroy: true

  validates_presence_of :entity_kind

  validates :entity_kind,
    inclusion: { in: ENTITY_KINDS, message: "%{value} is not a valid business entity kind" },
    allow_blank: false

  validate :writing_agent_employed_by_broker

  scope :active, ->{ where(:is_active => true) }

  def parent
    raise "undefined parent Organization" unless organization?
    return @organization if defined? @organization
    @organization = self.organization
  end

  def employee_roles
    return @employee_roles if defined? @employee_roles
    @employee_roles = EmployeeRole.find_by_employer_profile(self)
  end

  # TODO - turn this in to counter_cache -- see: https://gist.github.com/andreychernih/1082313
  def roster_size
    employee_families.size
  end

  def latest_premium_statement
    return premium_statements.first if premium_statements.size == 1
    premium_statements.order_by(:'effective_on'.desc).limit(1).only(:premium_statements).first
  end

  # belongs_to broker_agency_profile
  def broker_agency_profile=(new_broker_agency_profile)
    raise ArgumentError.new("expected BrokerAgencyProfile") unless new_broker_agency_profile.is_a?(BrokerAgencyProfile)
    self.broker_agency_profile_id = new_broker_agency_profile._id
    new_broker_agency_profile
  end

  def broker_agency_profile
    return @broker_agency_profile if defined? @broker_agency_profile
    @broker_agency_profile =  parent.broker_agency_profile.where(id: @broker_agency_profile_id) unless @broker_agency_profile_id.blank?
  end

  # belongs_to writing agent (broker)
  def writing_agent=(new_writing_agent)
    raise ArgumentError.new("expected BrokerRole") unless new_writing_agent.is_a?(BrokerRole)
    self.writing_agent_id = new_writing_agent._id
    new_writing_agent
  end

  def writing_agent
    return @writing_agent if defined? @writing_agent
    @writing_agent = BrokerRole.find(@writing_agent_id) unless @writing_agent_id.blank?
  end

  # TODO: Benchmark this for efficiency
  def employee_families_sorted
    return @employee_families_sorted if defined? @employee_families_sorted
    @employee_families_sorted = employee_families.unscoped.order_by_last_name.order_by_first_name
  end

  def latest_plan_year
    plan_years.order_by(:'start_on'.desc).limit(1).only(:plan_years).first
  end

  def find_plan_year_by_date(coverage_date)
    # The #to_a is a caching thing.
    plan_years.to_a.detect do |py|
      (py.start_date <= coverage_date) &&
      (py.end_date   >= coverage_date)
    end
  end

  # Enrollable employees are active and unlinked
  def linkable_employee_family_by_person(person)
    return if employee_families.nil?

    employee_families.detect { |ef| (ef.census_employee.ssn == person.ssn) && (ef.census_employee.dob == person.dob) && (ef.is_linkable?) }
  end

  def is_active?
    self.is_active
  end

  def find_employee_by_person(person)
    return self.employee_families.select{|emf| emf.census_employee.ssn == person.ssn}.first.census_employee
  end

  ## Class methods
  class << self
    def list_embedded(parent_list)
      parent_list.reduce([]) { |list, parent_instance| list << parent_instance.employer_profile }
    end

    def all
      list_embedded Organization.exists(employer_profile: true).order_by([:legal_name]).to_a
    end

    def first
      all.first
    end

    def last
      all.last
    end

    def find(id)
      organizations = Organization.where("employer_profile._id" => BSON::ObjectId.from_string(id))
      organizations.size > 0 ? organizations.first.employer_profile : nil
    end

    def find_by_fein(fein)
      organization = Organization.where(fein: fein).first
      organization.present? ? organization.employer_profile : nil
    end

    def find_by_broker_agency_profile(profile)
      raise ArgumentError.new("expected BrokerAgencyProfile") unless profile.is_a?(BrokerAgencyProfile)
      list_embedded Organization.where("employer_profile.broker_agency_profile_id" => profile._id).to_a
    end

    def find_by_writing_agent(writing_agent)
      raise ArgumentError.new("expected BrokerRole") unless writing_agent.is_a?(BrokerRole)
      where(writing_agent_id: writing_agent._id) || []
    end

    def find_census_families_by_person(person)
      organizations = match_census_employees(person)
      organizations.reduce([]) do |families, er|
        families << er.employer_profile.employee_families.detect { |ef| ef.census_employee.ssn == person.ssn }
      end
    end

    # Returns all EmployerProfiles where person is active on the employee_census
    def find_all_by_person(person)
      organizations = match_census_employees(person)
      organizations.reduce([]) do |profiles, er|
        profiles << er.employer_profile
      end
    end

    def match_census_employees(person)
      raise ArgumentError.new("expected Person") unless person.respond_to?(:ssn) && person.respond_to?(:dob)
      return [] if person.ssn.blank? || person.dob.blank?
      Organization.and("employer_profile.employee_families.census_employee.ssn" => person.ssn,
                       "employer_profile.employee_families.census_employee.dob" => person.dob,
                       "employer_profile.employee_families.census_employee.linked_at" => nil).to_a
    end
  end

  def revert_plan_year
    plan_year.revert
  end

  def plan_year_publishable?
    latest_plan_year.valid?
  end

  def event_date_valid?
    is_valid = case aasm.current_event
      when :begin_open_enrollment
        Date.current.beginning_of_day >= latest_plan_year.open_enrollment_start_on.beginning_of_day
      when :end_open_enrollment
        Date.current.beginning_of_day >= latest_plan_year.open_enrollment_end_on.beginning_of_day
      else
        false
    end
    is_valid
  end

  def build_premium_statement
    self.premium_statements.build(effective_on: Date.current)
  end

  # TODO add all enrollment rules
  def enrollment_participation_met?
    latest_plan_year.fte_count <= HbxProfile::ShopSmallMarketMaximumFteCount
  end

## anonymous shopping
# no fein required
# no SSNs, names, relationships, required
# build-in geographic rating and tobacco - set defaults
## Broker tools
# sample census profiles
# ability to create library of templates for employer profiles

  # Workflow for self service
  aasm do
    state :applicant, initial: true 
    state :ineligible               # Unable to enroll business per SHOP market regulations or business isn't DC-based
    state :ineligible_appealing
    state :registered               # Business information complete, before initial open enrollment period
    state :enrolling                # Employees registering and plan shopping
    state :enrolled_renewal_ready   # Annual renewal date is 90 days or less
    state :enrolled_renewing        # 

    state :binder_pending
    state :enrolled                 # Enrolled and premium payment up-to-date
    state :canceled                 # Coverage didn't take effect, as Employer either didn't complete enrollment or pay binder premium
    state :suspended       # 
    state :terminated               # Premium payment > 90 days past due (day 91) or voluntarily terminate

    event :reapply do
      transitions from: :canceled, to: :applicant
      transitions from: :terminated, to: :applicant
    end

    event :publish_plan_year, :guards => [:plan_year_publishable?] do 
      transitions from: :applicant, to: :registered
      transitions from: :applicant, to: :ineligible
    end

    event :appeal do
      transitions from: :ineligible, to: :ineligible_appealing
    end

    # Initiated only by HBX Admin
    event :appeal_determination do
      transitions from: :ineligible_appealing, to: :ineligible

      # Add guard -- only revert for first 30 days past submitted
      transitions from: :ineligible_appealing, to: :applicant, 
        :after_enter => :revert_plan_year

      transitions from: :ineligible_appealing, to: :registered
    end

    event :begin_open_enrollment, :guards => [:event_date_valid?] do
      transitions from: :registered, to: :enrolling
    end

    event :end_open_enrollment, :guards => [:event_date_valid?] do
      transitions from: :enrolling, to: :binder_pending, 
        :guard => :enrollment_participation_met?,
        :after => :build_premium_statement

      transitions from: :enrolling, to: :canceled
    end

    event :cancel_coverage do
      transitions from: :registered, to: :canceled
      transitions from: :enrolling, to: :canceled
      transitions from: :binder_pending, to: :canceled
      transitions from: :ineligible, to: :canceled    # put guard: following 90 days in ineligible status
      transitions from: :enrolled, to: :canceled
    end

    event :enroll do
      transitions from: :binder_pending, to: :enrolled
    end

    event :prepare_for_renewal do
      transitions from: :enrolled, to: :enrolled_renewal_ready
    end

    event :renew do
      transitions from: :enrolled_renewal_ready, to: :enrolled_renewing
    end

    event :suspend_coverage do
      transitions from: :enrolled, to: :suspended
    end

    event :terminate_coverage do
      transitions from: :suspended, to: :terminated
      transitions from: :enrolled, to: :terminated
    end

    event :reinstate_coverage do
      transitions from: :suspended, to: :enrolled
      transitions from: :terminated, to: :enrolled
    end

    event :reenroll do
      transitions from: :terminated, to: :binder_pending
    end

  end

  def within_open_enrollment_for?(t_date, effective_date)
    plan_years.any? do |py|
      py.open_enrollment_contains?(t_date) &&
        py.coverage_period_contains?(effective_date)
    end
  end

private
  def writing_agent_employed_by_broker
    if writing_agent.present? && broker_agency.present?
      unless broker_agency.writing_agents.detect(writing_agent)
        errors.add(:writing_agent, "must be broker at broker_agency")
      end
    end
  end


end
