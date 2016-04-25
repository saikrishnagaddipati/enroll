class Insured::PlanShoppingsController < ApplicationController
  include ApplicationHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Context
  include Acapi::Notifiers
  extend Acapi::Notifiers
  include Aptc
  before_action :set_current_person, :only => [:receipt, :thankyou, :waive, :show, :plans, :smart_plans, :checkout]
  before_action :set_kind_for_market_and_coverage, only: [:thankyou, :show, :plans, :checkout, :receipt]

  def checkout

    plan_selection = PlanSelection.for_enrollment_id_and_plan_id(params.require(:id), params.require(:plan_id))

    if plan_selection.employee_is_shopping_before_hire?
      session.delete(:pre_hbx_enrollment_id)
      flash[:error] = "You are attempting to purchase coverage prior to your date of hire on record. Please contact your Employer for assistance"
      redirect_to family_account_path
      return
    end

    if !plan_selection.may_select_coverage?
      redirect_to :back
      return
    end

    get_aptc_info_from_session(plan_selection.hbx_enrollment)
    plan_selection.apply_aptc_if_needed(@shopping_tax_household, @elected_aptc, @max_aptc)
    previous_enrollment_id = session[:pre_hbx_enrollment_id]
    plan_selection.select_plan_and_deactivate_other_enrollments(previous_enrollment_id)
    session.delete(:pre_hbx_enrollment_id)
    redirect_to receipt_insured_plan_shopping_path(change_plan: params[:change_plan], enrollment_kind: params[:enrollment_kind])
  end

  def receipt
    person = @person

    @enrollment = HbxEnrollment.find(params.require(:id))
    plan = @enrollment.plan
    if @enrollment.is_shop?
      benefit_group = @enrollment.benefit_group
      reference_plan = @enrollment.coverage_kind == 'dental' ? benefit_group.dental_reference_plan : benefit_group.reference_plan

      if benefit_group.is_congress
        @plan = PlanCostDecoratorCongress.new(plan, @enrollment, benefit_group)
      else
        @plan = PlanCostDecorator.new(plan, @enrollment, benefit_group, reference_plan)
      end

      @employer_profile = @person.active_employee_roles.first.employer_profile
    else
      @shopping_tax_household = get_shopping_tax_household_from_person(@person, @enrollment.effective_on.year)
      @plan = UnassistedPlanCostDecorator.new(plan, @enrollment, @enrollment.applied_aptc_amount, @shopping_tax_household)
      @market_kind = "individual"
    end
    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
    @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''

    send_receipt_emails if @person.emails.first
  end

  def thankyou
    set_elected_aptc_by_params(params[:elected_aptc]) if params[:elected_aptc].present?
    set_consumer_bookmark_url(family_account_path)
    @plan = Plan.find(params.require(:plan_id))
    @enrollment = HbxEnrollment.find(params.require(:id))

    if @enrollment.is_special_enrollment?
      sep_id = @enrollment.is_shop? ? @enrollment.family.earliest_effective_shop_sep.id : @enrollment.family.earliest_effective_ivl_sep.id
      @enrollment.update_current(special_enrollment_period_id: sep_id)
    end

    if @enrollment.is_shop?
      @benefit_group = @enrollment.benefit_group
      @reference_plan = @enrollment.coverage_kind == 'dental' ? @benefit_group.dental_reference_plan : @benefit_group.reference_plan

      if @benefit_group.is_congress
        @plan = PlanCostDecoratorCongress.new(@plan, @enrollment, @benefit_group)
      else
        @plan = PlanCostDecorator.new(@plan, @enrollment, @benefit_group, @reference_plan)
      end
      @employer_profile = @person.active_employee_roles.first.employer_profile
    else
      get_aptc_info_from_session(@enrollment)
      if can_apply_aptc?(@plan)
        @plan = UnassistedPlanCostDecorator.new(@plan, @enrollment, @elected_aptc, @shopping_tax_household)
      else
        @plan = UnassistedPlanCostDecorator.new(@plan, @enrollment)
      end
    end
    @family = @person.primary_family
    #FIXME need to implement can_complete_shopping? for individual
    @enrollable = @market_kind == 'individual' ? true : @enrollment.can_complete_shopping?
    @waivable = @enrollment.can_complete_shopping?
    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
    @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''
    flash.now[:error] = qualify_qle_notice unless @enrollment.can_select_coverage?

    respond_to do |format|
      format.html { render 'thankyou.html.erb' }
    end
  end

  def sort
    respond_to do |format|
      format.js { render 'thankyou.html.erb' }
    end
  end

  def waive
    person = @person
    hbx_enrollment = HbxEnrollment.find(params.require(:id))
    waiver_reason = params[:waiver_reason]

    if hbx_enrollment.may_waive_coverage? && waiver_reason.present? && hbx_enrollment.valid?
      hbx_enrollment.update_current(aasm_state: "inactive", waiver_reason: waiver_reason)
      hbx_enrollment.propogate_waiver
      redirect_to print_waiver_insured_plan_shopping_path(hbx_enrollment), notice: "Waive Coverage Successful"
    else
      redirect_to new_insured_group_selection_path(person_id: @person.id, change_plan: 'change_plan', hbx_enrollment_id: hbx_enrollment.id), alert: "Waive Coverage Failed"
    end
  end

  def print_waiver
    @hbx_enrollment = HbxEnrollment.find(params.require(:id))
  end

  def terminate
    hbx_enrollment = HbxEnrollment.find(params.require(:id))

    if hbx_enrollment.may_terminate_coverage?
      hbx_enrollment.update_current(aasm_state: "coverage_terminated", terminated_on: TimeKeeper.date_of_record.end_of_month)
      hbx_enrollment.propogate_terminate

      redirect_to family_account_path
    else
      redirect_to :back
    end
  end

  def show
    set_plans_by(hbx_enrollment_id: params.require(:id))
    @multiplyer = params[:rating].to_i
    @sort = params[:sort]
    @plans.each do |plan|
        plan.assign_attributes({ :estimated_out_of_pocket => (plan.total_employee_cost*@multiplyer) })
      end
    @plan = @plans.first
    set_consumer_bookmark_url(family_account_path) if params[:market_kind] == 'individual'
    set_employee_bookmark_url(family_account_path) if params[:market_kind] == 'shop'
    hbx_enrollment_id = params.require(:id)
    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
    @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''

    set_plans_by(hbx_enrollment_id: hbx_enrollment_id)
    shopping_tax_household = get_shopping_tax_household_from_person(@person, @hbx_enrollment.effective_on.year)

    if shopping_tax_household.present? && @hbx_enrollment.coverage_kind == "health"
      @tax_household = shopping_tax_household
      @max_aptc = @tax_household.total_aptc_available_amount_for_enrollment(@hbx_enrollment)
      session[:max_aptc] = @max_aptc
      @elected_aptc = session[:elected_aptc] = @max_aptc * 0.85
    else
      session[:max_aptc] = 0
      session[:elected_aptc] = 0
    end

    @carriers = @carrier_names_map.values
    @waivable = @hbx_enrollment.try(:can_complete_shopping?)
    @max_total_employee_cost = thousand_ceil(@plans.map(&:total_employee_cost).map(&:to_f).max)
    @max_deductible = thousand_ceil(@plans.map(&:deductible).map {|d| d.is_a?(String) ? d.gsub(/[$,]/, '').to_i : 0}.max)
  end

  def set_elected_aptc
    session[:elected_aptc] = params[:elected_aptc].to_f
    render json: 'ok'
  end

  def smart_plans
    @sort = "Custom Filter"
    @multiplyer = params[:multiplyer].to_i
    case @multiplyer
    when 1
      @multiplyer = 1.33
    when 2
      @multiplyer = 1.5
    when 3
      @multiplyer = 2
    end
    @hbx_enrollment = HbxEnrollment.find(params[:hbx_enrollment])
    smart_plans = []
    params[:plans].each do |plan|
      p = Plan.where(id: plan)
      p = p.collect {|plan| UnassistedPlanCostDecorator.new(plan, @hbx_enrollment)}
      smart_plans << p.first
    end
    @plans = smart_plans.to_a
    respond_to do |format|
      format.js { render 'insured/plan_shoppings/smart_plans.js.erb' }
    end
  end

  def plans
    @multiplyer = params[:rating].to_i
    case @multiplyer
    when 1
      @multiplyer = 1.33
    when 2
      @multiplyer = 1.5
    when 3
      @multiplyer = 2
    end
    @sort = params[:sort]

    set_consumer_bookmark_url(family_account_path)

    set_plans_by(hbx_enrollment_id: params.require(:id)) unless params[:smart_plans] == "smart_plans"
    if params[:sort].present?
    case @sort
      when 'premium'
        @plans = @plans.sort_by(&:total_employee_cost).sort{|a,b| b.csr_variant_id <=> a.csr_variant_id}
      when 'estimated_out_of_pocket'
        @plans.each do |plan|
            plan.assign_attributes({ :estimated_out_of_pocket => (plan.total_employee_cost*@multiplyer) })
          end
        @plans = @plans.sort_by(&:estimated_out_of_pocket).sort{|a,b| b.csr_variant_id <=> a.csr_variant_id}
      when 'maximum_cost'
        @plans.each do |plan|
          moop = maximum_out_of_pocket(plan)
          premium = current_cost(plan.total_employee_cost*12, plan.ehb, nil, 'shopping', plan.can_use_aptc?)

          if @person.primary_family.active_family_members.count > 1
            maximum_out_of_pocket = moop.in_network_tier_1_individual_amount.gsub(/[$,]/, '').to_f + premium
            plan.assign_attributes({ :maximum_out_of_pocket => maximum_out_of_pocket })
          else
            maximum_out_of_pocket = moop.in_network_tier_1_family_amount.gsub(/[$,]/, '').to_f + premium
            plan.assign_attributes({ :maximum_out_of_pocket => maximum_out_of_pocket })
          end
        end
        @plans = @plans.sort_by(&:maximum_out_of_pocket).sort{|a,b| b.csr_variant_id <=> a.csr_variant_id}
      end
      @plan_hsa_status = Products::Qhp.plan_hsa_status_map(@plans)
      respond_to do |format|
        format.js { render 'insured/plan_shoppings/plans.js.erb' }
      end
    else
      @plans = @plans.sort_by(&:total_employee_cost).sort{|a,b| b.csr_variant_id <=> a.csr_variant_id}
      @plans = @plans.partition{ |a| @enrolled_hbx_enrollment_plan_ids.include?(a[:id]) }.flatten
      @plan_hsa_status = Products::Qhp.plan_hsa_status_map(@plans)
    end
    @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
    @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''
  end

  private

  def maximum_out_of_pocket(plan)
    csv = Products::QhpCostShareVariance.find_qhp_cost_share_variances(["#{plan.hios_id}"], 2016, "health").first
    moop = csv.qhp_maximum_out_of_pockets.where(name: "Maximum Out of Pocket for Medical and Drug EHB Benefits (Total)").last
  end

  def send_receipt_emails
    # UserMailer.plan_shopping_completed(@person.user, @person.hbx_id).deliver_now
    UserMailer.generic_consumer_welcome(@person.first_name, @person.hbx_id, @person.emails.first.address).deliver_now
    body = render_to_string 'user_mailer/secure_purchase_confirmation.html.erb', layout: false
    from_provider = HbxProfile.current_hbx
    message_params = {
      sender_id: from_provider.try(:id),
      parent_message_id: @person.id,
      from: from_provider.try(:legal_name),
      to: @person.full_name,
      body: body,
      subject: 'Your Secure Enrollment Confirmation'
    }
    create_secure_message(message_params, @person, :inbox)
  end

  def set_plans_by(hbx_enrollment_id:)
    if @person.nil?
      @enrolled_hbx_enrollment_plan_ids = []
    else
      @enrolled_hbx_enrollment_plan_ids = @person.primary_family.enrolled_hbx_enrollments.map(&:plan).map(&:id)
    end

    Caches::MongoidCache.allocate(CarrierProfile)
    @hbx_enrollment = HbxEnrollment.find(hbx_enrollment_id)
    if @hbx_enrollment.blank?
      @plans = []
    else
      if @market_kind == 'shop'
        @benefit_group = @hbx_enrollment.benefit_group
        @plans = @benefit_group.decorated_elected_plans(@hbx_enrollment, @coverage_kind)
      elsif @market_kind == 'individual'
        @plans = @hbx_enrollment.decorated_elected_plans(@coverage_kind)
      end
    end
    # for carrier search options
    carrier_profile_ids = @plans.map(&:carrier_profile_id).map(&:to_s).uniq
    @carrier_names_map = Organization.valid_carrier_names_filters.select{|k, v| carrier_profile_ids.include?(k)}
  end

  def thousand_ceil(num)
    return 0 if num.blank?
    (num.fdiv 1000).ceil * 1000
  end

  def set_kind_for_market_and_coverage
    @market_kind = params[:market_kind].present? ? params[:market_kind] : 'shop'
    @coverage_kind = params[:coverage_kind].present? ? params[:coverage_kind] : 'health'
  end

  def get_aptc_info_from_session(hbx_enrollment)
    @shopping_tax_household = get_shopping_tax_household_from_person(@person, hbx_enrollment.effective_on.year) if @person.present?
    if @shopping_tax_household.present?
      @max_aptc = session[:max_aptc].to_f
      @elected_aptc = session[:elected_aptc].to_f
    else
      @max_aptc = 0
      @elected_aptc = 0
    end
  end

  def can_apply_aptc?(plan)
    @shopping_tax_household.present? and @elected_aptc > 0 and plan.present? and plan.can_use_aptc?
  end

  def set_elected_aptc_by_params(elected_aptc)
    if session[:elected_aptc].to_f != elected_aptc.to_f
      session[:elected_aptc] = elected_aptc.to_f
    end
  end
end
