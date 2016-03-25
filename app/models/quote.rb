class Quote
  include Mongoid::Document
  include Mongoid::Timestamps
  include MongoidSupport::AssociationProxies

  PERSONAL_RELATIONSHIP_KINDS = [
    :employee,
    :spouse,
    :domestic_partner,
    :child_under_26,
    :child_26_and_over
  ]

  PLAN_OPTION_KINDS = %w(single_plan single_carrier metal_level)

  field :quote_name, type: String
  field :plan_year, type: Integer

  field :start_on, type: Date

  field :broker_agency_profile_id, type: BSON::ObjectId




  associated_with_one :broker_agency_profile, :broker_agency_profile_id, "BrokerAgencyProfile"

  field :plan_option_kind, type: String

  embeds_many :quote_reference_plans, cascade_callbacks: true
  embeds_many :quote_households

  embeds_many :quote_relationship_benefits, cascade_callbacks: true

  def calc
    #plans = Plan.limit(10).where("active_year"=>2016,"coverage_kind"=>"health")

    #plans.each do |p|
    #  puts p.id
    #  puts Caches::PlanDetails.lookup_rate(p.id, TimeKeeper.date_of_record, 18)
    #end

#Caches::PlanDetails.lookup_rate("56e6c4e53ec0ba9613008f6d", Date.new(2016,5,1), 35)
#Caches::PlanDetails.lookup_rate(ObjectId("56e6c4e53ec0ba9613008f6d"), TimeKeeper.date_of_record, 18)

#[7] pry(main)> Caches::PlanDetails.lookup_rate(BSON::ObjectId("56e6c4e53ec0ba9613008f6d"), Date.new(2016,5,1), 35)

#[8] pry(main)> Caches::PlanDetails.lookup_rate(BSON::ObjectId("56e6c4e53ec0ba9613008f6d"), Date.new(2016,5,1), 4)

    #self.plan_option_kind = "single_plan"

    #rp1 = self.quote_reference_plans.build(reference_plan_id:  "56e6c4e53ec0ba9613008f6d")
    #rp1.set_bounding_cost_plans
    #rp1.save



    self.plan_option_kind = "single_carrier"
    self.plan_year = 2016

    self.start_on = Date.new(2016,5,2)
    
    rp1 = self.quote_reference_plans.build(reference_plan_id:  "56e6c4e53ec0ba9613008f6d")
    rp1.set_bounding_cost_plans
    rp1.save
    #reference_plan=("56e6c4e53ec0ba9613008f6d")

    p = Plan.find(self.quote_reference_plans[0].reference_plan_id)

    puts "Calculating details for " + p.name

      self.quote_households.each do |hh|
        puts "   " + hh.quote_members.first.first_name
        pcd = PlanCostDecorator.new(p, hh, self, p)
        puts "Employee Cost " + pcd.total_employee_cost.to_s
        puts "Employer Contribution " + pcd.total_employer_contribution.to_s

        rp1.quote_results << pcd.get_family_details
      end

      self.save

  end

  def gen_data

    build_relationship_benefits
    self.relationship_benefit_for("employee").premium_pct=(70)
    self.relationship_benefit_for("child_under_26").premium_pct=(70)

    qh = self.quote_households.build

    qm = qh.quote_members.build

    qm.first_name = "Tony"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1980,7,26)
    qm.employee_relationship = "employee"

    qm = qh.quote_members.build

    qm.first_name = "Gabriel"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Steve"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Lucas"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Enzo"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"

    qm = qh.quote_members.build

    qm.first_name = "Leonardo"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1990,1,10)
    qm.employee_relationship = "child_under_26"

    self.save

    qh = self.quote_households.build
    qm = qh.quote_members.build

    qm.first_name = "Andressa"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1988,9,27)
    qm.employee_relationship = "employee"

    qm = qh.quote_members.build

    qm.first_name = "Alice"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2014,1,13)
    qm.employee_relationship = "child_under_26"
    self.save

    self.calc

  end

  def build_relationship_benefits
    self.quote_relationship_benefits = PERSONAL_RELATIONSHIP_KINDS.map do |relationship|
       self.quote_relationship_benefits.build(relationship: relationship, offered: true)
    end
  end

  def calc_by_plan(plan_id)

    if quote_households.exists?

      quote_households.each do |hh|
        puts "Found household of size " + hh.quote_members.count.to_s
      end
    end
  end

  def relationship_benefit_for(relationship)
    quote_relationship_benefits.where(relationship: relationship).first
  end

  def gen_data

    build_relationship_benefits

    qh = self.quote_households.build

    qm = qh.quote_members.build

    qm.first_name = "Tony"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(1980,7,26)
    qm.employee_relationship = "employee"

    qm = qh.quote_members.build

    qm.first_name = "Gabriel"
    qm.last_name = "Schaffert"
    qm.dob = Date.new(2012,1,10)
    qm.employee_relationship = "child_under_26"
    self.save

    self.calc
    #qh = self.quote_households.build
    #qm = qh.quote_members.build

    #qm.first_name = "Andressa"
    #qm.last_name = "Schaffert"
    #qm.dob = Date.new(1988,9,27)
    #qm.employee_relationship = "self"

    #qm = qh.quote_members.build

    #qm.first_name = "Alice"
    #qm.last_name = "Schaffert"
    #qm.dob = Date.new(2014,1,13)
    #qm.employee_relationship = "child_under_26"
    #self.save


  end

  def build_relationship_benefits
    self.quote_relationship_benefits = PERSONAL_RELATIONSHIP_KINDS.map do |relationship|
       self.quote_relationship_benefits.build(relationship: relationship, offered: true)
    end
  end

  def calc_by_plan(plan_id)

    if quote_households.exists?

      quote_households.each do |hh|
        puts "Found household of size " + hh.quote_members.count.to_s
      end
    end
  end

  def relationship_benefit_for(relationship)
    quote_relationship_benefits.where(relationship: relationship).first
  end

end