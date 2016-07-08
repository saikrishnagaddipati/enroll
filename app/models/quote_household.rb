class QuoteHousehold
  include Mongoid::Document
  include Mongoid::Timestamps
  include MongoidSupport::AssociationProxies

  embedded_in :quote
  embeds_many :quote_members

  field :family_id, type: String

  validate :uniqueness_of_employee, :uniqueness_of_spouse_or_domestic_partner

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

end
