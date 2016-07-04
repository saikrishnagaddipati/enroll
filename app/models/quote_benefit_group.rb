class QuoteBenefitGroup
  include Mongoid::Document

  PERSONAL_RELATIONSHIP_KINDS = [
    :employee,
    :spouse,
    :domestic_partner,
    :child_under_26,
    :child_26_and_over
  ]

  embedded_in :quote

  field :title, type: String, default: "My Benefit Group"
  field :default, type: Boolean, default: false

  field :plan_option_kind, type: String, default: "single_carrier"
  field :dental_plan_option_kind, type: String, default: "single_carrier"

  field :contribution_pct_as_int, type: Integer, default: 0
  field :employee_max_amt, type: Money, default: 0
  field :first_dependent_max_amt, type: Money, default: 0
  field :over_one_dependents_max_amt, type: Money, default: 0


  field :reference_plan_id, type: BSON::ObjectId
  field :lowest_cost_plan_id, type: BSON::ObjectId
  field :highest_cost_plan_id, type: BSON::ObjectId


  embeds_many :quote_relationship_benefits, cascade_callbacks: true

  def relationship_benefit_for(relationship)
    quote_relationship_benefits.where(relationship: relationship).first
  end

  def build_relationship_benefits
    self.quote_relationship_benefits = PERSONAL_RELATIONSHIP_KINDS.map do |relationship|
       self.quote_relationship_benefits.build(relationship: relationship, offered: true)
    end
  end

  def reference_plan=(new_reference_plan)
    raise ArgumentError.new("expected Plan") unless new_reference_plan.is_a? Plan
    self.reference_plan_id = new_reference_plan._id
  end

  def reference_plan
    return @reference_plan if defined? @reference_plan
    @reference_plan = Plan.find(reference_plan_id) unless reference_plan_id.nil?
  end

  def set_bounding_cost_plans
    return if reference_plan_id.nil?

      if quote.plan_option_kind == "single_plan"
        plans = [reference_plan]
      else
        if quote.plan_option_kind == "single_carrier"
          plans = Plan.shop_health_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile)
        else
          plans = Plan.shop_health_by_active_year(reference_plan.active_year).by_health_metal_levels([reference_plan.metal_level])
        end
      end

      if plans.size > 0
        plans_by_cost = plans.sort_by { |plan| plan.premium_tables.first.cost }

        self.lowest_cost_plan_id  = plans_by_cost.first.id
        self.highest_cost_plan_id = plans_by_cost.last.id
      end
  end

end
