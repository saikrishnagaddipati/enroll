class QuoteHousehold
  include Mongoid::Document
  include Mongoid::Timestamps
  include MongoidSupport::AssociationProxies

  embedded_in :quote
  embeds_many :quote_members

  field :family_id, type: String

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

end
