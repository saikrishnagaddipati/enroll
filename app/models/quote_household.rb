class QuoteHousehold
  include Mongoid::Document
  include Mongoid::Timestamps
  include MongoidSupport::AssociationProxies

  embedded_in :quote
  embeds_many :quote_members

  field :family_id, type: String

  validate :uniqueness_of_employee, :uniqueness_of_spouse_or_domestic_partner

  # Quote Benefit Group ID for this employee on the roster
  field :quote_benefit_group_id, type: BSON::ObjectId

  validates_uniqueness_of :family_id

  before_save :assign_benefit_group_id

  accepts_nested_attributes_for :quote_members

  def employee?
    quote_members.where("employee_relationship" => "employee").count == 1 ? true : false
  end

  def spouse?
    quote_members.where("employee_relationship" => "spouse").count == 1 ? true : false
  end

  def children?
    quote_members.where("employee_relationship" => "child_under_26").count > 1 ? true : false
  end

  def employee
    quote_members.where("employee_relationship" => "employee").first
  end

  private

  def uniqueness_of_spouse_or_domestic_partner
    if quote_members.where(:employee_relationship => { "$in" => ["spouse" , "domestic_partner"]}).count > 1
      errors.add(:"quote_members.employee_relationship","Should be unique")
    end
  end

  def uniqueness_of_employee
    if quote_members.where("employee_relationship" => "employee").count > 1
      errors.add(:"quote_members.employee_relationship","There should be only one employee per family.")
    end
  end

  def assign_benefit_group_id
    puts "Assigining Benefit Group IDs"
    if quote_benefit_group_id.nil?
      puts "quote.quote_benefit_groups.first.id: " + quote.quote_benefit_groups.first.id.to_s
      self.quote_benefit_group_id = quote.quote_benefit_groups.first.id
      puts "quote_benefit_group_id " + quote_benefit_group_id.to_s
    end
  end

end
