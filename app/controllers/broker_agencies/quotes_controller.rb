class BrokerAgencies::QuotesController < ApplicationController

  before_action :find_quote , :only => [:destroy ,:show, :delete_member, :delete_household, :publish_quote, :view_published_quote]
  before_action :format_date_params  , :only => [:update,:create]
  before_action :employee_relationship_map

  def view_published_quote

  end

  def publish_quote
    @params = params.inspect


    if @quote.may_publish?

      @quote.plan_option_kind = params[:plan_option_kind].gsub(' ','_').downcase
      @quote.published_reference_plan = Plan.find(params[:reference_plan_id]).id
      @quote.publish
      @quote.save!
    end

    render "publish_quote" , :flash => {:notice => "Quote Published" }

  end

  def index
    @quotes = Quote.where("broker_role_id" => current_user.person.broker_role.id, "aasm_state" => "draft")
    @all_quotes = Quote.where("broker_role_id" => current_user.person.broker_role.id)
    active_year = Date.today.year
    @coverage_kind = "health"
    #@plans =  Plan.shop_health_by_active_year(active_year)
    @plans = $quote_shop_health_plans


    @plan_quote_criteria  = []
    @bp_hash = {'employee':50, 'spouse': 0, 'domestic_partner': 0, 'child_under_26': 0, 'child_26_and_over': 0}
    # if !params['plans'].nil? && params['plans'].count > 0

    #   @q =  Quote.find(params[:quote]) #Quote.find(Quote.first.id)
    #   @benefit_pcts = @q.quote_relationship_benefits
    #   @benefit_pcts.each{|bp| @bp_hash[bp.relationship] = bp.premium_pct}
    #@q = nil
    @q =  Quote.find(params[:quote]) if !params[:quote].nil?#Quote.find(Quote.first.id)
    if !params['plans'].nil? && params['plans'].count > 0 && params["commit"].downcase == "compare costs"
      @quote_results = Hash.new
      @quote_results_summary = Hash.new
      unless @q.nil?
        params['plans'].each do |plan_id|
          p = Plan.find(plan_id)
          detailCost = Array.new
          @q.quote_households.each do |hh|
            pcd = PlanCostDecorator.new(p, hh, @q, p)
            detailCost << pcd.get_family_details_hash.sort_by { |m| [m[:family_id], -m[:age], -m[:employee_contribution]] }
          end
          @quote_results[p.name] = {:detail => detailCost, :total_employee_cost => @q.roster_employee_cost(p,p), :total_employer_cost => @q.roster_employer_contribution(p,p), plan_id: plan_id}
          @quote_results_summary[p.name] = @q.cost_by_offerings(p)
        end
          @quote_results_summary = @quote_results_summary.sort_by { |k, v| v["reference_plan_cost"] }
          @quote_results = @quote_results.sort_by { |k, v| v[:total_employer_cost] }.to_h
      end
    elsif !params['plans'].nil? && params['plans'].count > 0 && params["commit"].downcase == "compare plans"
      @visit_types = @coverage_kind == "health" ? Products::Qhp::VISIT_TYPES : Products::Qhp::DENTAL_VISIT_TYPES
      standard_component_ids = get_standard_component_ids
      @qhps = Products::QhpCostShareVariance.find_qhp_cost_share_variances(standard_component_ids, active_year, "Health")
    end

    @display_results = @quote_results.present? || @qhps.present?
    #else
    #TODO OPTIONAL CACHE/REFACTOR
    @plans.each{|p| @plan_quote_criteria << [p.metal_level, p.carrier_profile.organization.legal_name, p.plan_type,
     p.deductible.gsub(/\$/,'').gsub(/,/,'').to_i, p.id.to_s, p.carrier_profile.abbrev, p.nationwide, p.dc_in_network]
    }
    @metals =      @plan_quote_criteria.map{|p| p[0]}.uniq.append('any')
    @carriers =    @plan_quote_criteria.map{|p| [ p[1], p[5] ] }.uniq.append(['any','any'])
    @plan_types =  @plan_quote_criteria.map{|p| p[2]}.uniq.append('any')
    @dc_network =  ['true', 'false', 'any']
    @nationwide =  ['true', 'false', 'any']
    @select_detail = @plan_quote_criteria.to_json
    @max_deductible = 6000
    quote_on_page = @q || @quotes.first
    @quote_criteria = []
    unless quote_on_page.nil?
      quote_on_page.quote_relationship_benefits.each{|bp| @bp_hash[bp.relationship] = bp.premium_pct} if
      @roster_premiums_json = quote_on_page.roster_cost_all_plans.to_json
      @quote_criteria = quote_on_page.criteria_for_ui
    end
    @benefit_pcts_json = @bp_hash.to_json
  end

  def edit
    #find quote to edit
    @quote = Quote.find(params[:id])

    # Create place holder for a new household and new member for the roster
    qhh = QuoteHousehold.new
    qm = QuoteMember.new
    qhh.quote_members << qm
    @quote.quote_households << qhh
  end

  def new
    @quote = Quote.new
    qhh = QuoteHousehold.new
    qm = QuoteMember.new
    qhh.quote_members << qm
    @quote.quote_households << qhh
  end

  def update
    @quote = Quote.find(params[:id])

    sanitize_quote_roster_params

    update_params = quote_params
    insert_params = quote_params

    update_params[:quote_households_attributes] = update_params[:quote_households_attributes].select {|k,v| update_params[:quote_households_attributes][k][:id].present?}
    insert_params[:quote_households_attributes] = insert_params[:quote_households_attributes].select {|k,v| insert_params[:quote_households_attributes][k][:id].blank?}

    if (@quote.update_attributes(update_params) && @quote.update_attributes(insert_params))
      redirect_to edit_broker_agencies_quote_path(@quote) ,  :flash => { :notice => "Successfully updated the employee roster" }
    else
      render "edit" , :flash => {:error => "Unable to update the employee roster" }
    end
  end

  def create
    quote = Quote.new(quote_params)
    quote.build_relationship_benefits
    quote.broker_role_id= current_user.person(:try).broker_role.id
    if quote.save
      redirect_to  broker_agencies_quotes_root_path ,  :flash => { :notice => "Successfully saved the employee roster" }
    else
      render "new" , :flash => {:error => "Unable to save the employee roster" }
    end
  end

  def plan_comparison
    puts params
    active_year = Date.today.year
    @coverage_kind = "health"
    @visit_types = @coverage_kind == "health" ? Products::Qhp::VISIT_TYPES : Products::Qhp::DENTAL_VISIT_TYPES
    standard_component_ids = get_standard_component_ids
    @qhps = Products::QhpCostShareVariance.find_qhp_cost_share_variances(standard_component_ids, active_year, "Health")
    sort_by = params[:sort_by]
    order = sort_by == session[:sort_by_copay] ? -1 : 1
    session[:sort_by_copay] = order == 1 ? sort_by : ''
    if sort_by
      sort_by = sort_by.strip
      sort_array = []
      @qhps.each do |qhp|
        sort_array.push( [qhp, get_visit_cost(qhp,sort_by)]  )
      end
      sort_array.sort!{|a,b| a[1]*order <=> b[1]*order}
      @qhps = sort_array.map{|item| item[0]}
    end
    render partial: 'plan_comparision', layout: false, locals: {qhps: @qhps}
  end

  def show
    @quote = Quote.find(params[:id])
  end

  def build_employee_roster
    @employee_roster = parse_employee_roster_file
    @quote= Quote.new
    if @employee_roster.is_a?(Array)
      @employee_roster.each do |member|
        @quote_household = @quote.quote_households.where(:family_id => member[0]).first
        @quote_household= QuoteHousehold.new(:family_id => member[0]) if @quote_household.nil?
        @quote_members= QuoteMember.new(:employee_relationship => member[1], :dob => member[2])
        @quote_household.quote_members << @quote_members
        @quote.quote_households << @quote_household
      end
    end
  end

  def upload_employee_roster
  end

  def download_employee_roster
    @quote = Quote.find(params[:id])
    @employee_roster = @quote.quote_households.map(&:quote_members).flatten
    send_data(csv_for(@employee_roster), :type => 'text/csv; charset=iso-8859-1; header=present',
    :disposition => "attachment; filename=Employee_Roster.csv")
  end

  def destroy
    if @quote.destroy
      respond_to do |format|
        format.js { render :text => "deleted Successfully" , :status => 200 }
      end
    end
  end

  def delete_member
    @qh = @quote.quote_households.find(params[:household_id])
    if @qh
      if @qh.quote_members.find(params[:member_id]).delete
        respond_to do |format|
          format.js { render :nothing => true}
        end
      end
    end
  end

  def delete_household
    @qh = @quote.quote_households.find(params[:household_id])
    if @qh.destroy
      respond_to do |format|
        format.js { render :nothing => true }
      end
    end
  end


  def new_household
    @quote = Quote.new
    @quote.quote_households.build
  end

  def update_benefits
    q = Quote.find(params['id'])
    benefits = params['benefits']
    q.quote_relationship_benefits.each {|b|
      b.update_attributes!(premium_pct: benefits[b.relationship])
    }

    @plans =  Plan.shop_health_by_active_year(2016)

    costs= []
    #@plans.each{ |plan|
    # TODOJF takes 5 seconds, needs caching.
    #  costs << [plan.id, q.roster_employee_cost(plan.id) ]
    #}

    render json:  costs.to_json
  end


  def get_quote_info

    @bp_hash = {}
    @q =  Quote.find(params[:quote])
    @q.quote_relationship_benefits.each{|bp| @bp_hash[bp.relationship] = bp.premium_pct}
    render json: {'relationship_benefits' => @bp_hash, 'roster_premiums' => @q.roster_cost_all_plans, 'criteria' => JSON.parse(@q.criteria_for_ui)}
  end

  def publish
    @quote = Quote.find(params[:quote_id])
    @plan = Plan.find(params[:plan_id][8,100])
    @elected_plan_choice = ['na', 'Single Plan', 'Single Carrier', 'Metal Level'][params[:elected].to_i]
    case @elected_plan_choice
      when 'Single Carrier'
        @offering_param  = @plan.name
      when 'Metal Level'
        @offering_param  = @plan.metal_level.capitalize
      else
        @offering_param = ""
    end

    @cost = params[:cost]
    @plans_offered = @quote.cost_for_plans(@quote.plan_by_offerings(@plan, @elected_plan_choice), @plan).sort_by { |k| [k["employer_cost"], k["employee_cost"]] }

  end

  def criteria
    if params[:quote_id]
      q = Quote.find(params[:quote_id])
      criteria_for_ui = params[:criteria_for_ui]
      q.update_attributes!(criteria_for_ui: criteria_for_ui ) if criteria_for_ui
      render json: JSON.parse(q.criteria_for_ui)
    else
      render json: []
    end
  end


private

  def employee_relationship_map
    @employee_relationship_map = {"employee" => "Employee", "spouse" => "Spouse", "domestic_partner" => "Domestic Partner", "child_under_26" => "Child"}
  end

 def get_standard_component_ids
  Plan.where(:_id => { '$in': params[:plans] } ).map(&:hios_id)
 end

 def quote_params
    params.require(:quote).permit(
                    :quote_name,
                    :start_on,
                    :broker_role_id,
                    :quote_households_attributes => [ :id, :family_id ,
                                       :quote_members_attributes => [ :id, :first_name ,:dob,
                                                                      :employee_relationship,:_delete ] ] )
 end

 def format_date_params
  params[:quote][:start_on] =  Date.strptime(params[:quote][:start_on],"%m/%d/%Y") if params[:quote][:start_on]
  if params[:quote][:quote_households_attributes]
    params[:quote][:quote_households_attributes].values.each do |household_attribute|
      unless household_attribute.nil?
        household_attribute[:quote_members_attributes].values.map { |m| m[:dob] = Date.strptime(m[:dob],"%m/%d/%Y") unless m[:dob] && m[:dob].blank?}
      end
    end
  end
 end



 def sanitize_quote_roster_params
   params[:quote][:quote_households_attributes].each do |key, fid|
     params[:quote][:quote_households_attributes].delete(key) if fid['family_id'].blank?
   end
 end

  def employee_roster_group_by_family_id
    params[:employee_roster].inject({}) do  |new_hash,e|
      new_hash[e[1][:family_id]].nil? ? new_hash[e[1][:family_id]] = [e[1]]  : new_hash[e[1][:family_id]] << e[1]
      new_hash
    end
  end

  def find_quote
    @quote = Quote.find(params[:id])
  end

  def parse_employee_roster_file
    begin
      CSV.parse(params[:employee_roster_file].read) if params[:employee_roster_file].present?
    rescue Exception => e
      flash[:error] = "Unable to parse the csv file"
      #redirect_to :action => "new" and return
    end
  end

  def csv_for(employee_roster)
    (output = "").tap do
      CSV.generate(output) do |csv|
        csv << ["FamilyID", "Relationship", "DOB"]
        employee_roster.each do |employee|
          csv << [  employee.family_id,
                    employee.employee_relationship,
                    employee.dob
                  ]
        end
      end
    end
  end

  def dollar_value copay
    return 10000 if copay == 'Not Applicable'
    cost = 0
    cost += 1000 if copay.match(/after deductible/)
    return cost if copay.match(/No charge/)
    dollars = copay.match(/(\d+)/)
    cost += (dollars && dollars[1]).to_i || 0
  end

  def get_visit_cost qhp_cost_share_variance, visit_type
    service_visit = qhp_cost_share_variance.qhp_service_visits.detect{|v| visit_type == v.visit_type }
    cost = dollar_value service_visit.copay_in_network_tier_1
  end
end
