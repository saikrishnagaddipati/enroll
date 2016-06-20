class HbxAdminController < ApplicationController
  $months_array = Date::ABBR_MONTHNAMES.compact

  def edit_aptc_csr
    raise NotAuthorizedError if !current_user.has_hbx_staff_role?
    @current_year = params[:year_selected]  || TimeKeeper.date_of_record.year
    @person = Person.find(params[:person_id])
    @family = Family.find(params[:family_id])
    @hbx = HbxEnrollment.find(params[:hbx_enrollment_id]) if params[:hbx_enrollment_id].present?
    @hbxs = @family.active_household.hbx_enrollments_with_aptc_by_year(@current_year)
    @slcsp_value = HbxAdmin.calculate_slcsp_value(@family)
    @household_members = HbxAdmin.build_household_members(@family)
    @household_info = HbxAdmin.build_household_level_aptc_csr_data(@family, @hbxs)
    @enrollments_info = HbxAdmin.build_enrollments_data(@family, @hbxs) if @hbxs.present?
    @current_aptc_applied_hash =  HbxAdmin.build_current_aptc_applied_hash(@hbxs)
    @aptc_applied_for_all_hbxs = @family.active_household.hbx_enrollments_with_aptc_by_year(@current_year).map{|h| h.applied_aptc_amount.to_f}.sum || 0
    @plan_premium_for_enrollments = HbxAdmin.build_plan_premium_hash_for_enrollments(@hbxs)
    @active_tax_household_for_current_year = @family.active_household.latest_active_tax_household_with_year(@current_year)
    @max_aptc = @family.active_household.latest_active_tax_household_with_year(@current_year).try(:latest_eligibility_determination).try(:max_aptc)
    @csr_percent_as_integer = @family.active_household.latest_active_tax_household_with_year(@current_year).try(:latest_eligibility_determination).try(:csr_percent_as_integer)
    respond_to do |format|
      format.js { render (@hbxs.blank? ? "edit_aptc_csr_no_enrollment" : "edit_aptc_csr_active_enrollment")}
    end
  end

  def update_aptc_csr
    raise NotAuthorizedError if !current_user.has_hbx_staff_role?
    @person = Person.find(params[:person][:person_id]) if params[:person].present? && params[:person][:person_id].present?
    @family = Family.find(params[:person][:family_id]) if params[:person].present? && params[:person][:family_id].present?
    if @family.present?
      @eligibility_redetermination_result = HbxAdmin.redetermine_eligibility_with_updated_values(@family, params)
      @enrollment_update_result = HbxAdmin.update_aptc_applied_for_enrollments(params)
    end
    respond_to do |format|
      format.js { render "update_aptc_csr", person: @person}
    end
  end

  # For AJAX Calculations.
  def calculate_aptc_csr
    raise NotAuthorizedError if !current_user.has_hbx_staff_role?
    @aptc_errors = HbxAdmin::build_error_messages(params[:max_aptc], params[:csr_percentage], params[:applied_aptcs_array])
    @current_year = params[:year_selected]  || TimeKeeper.date_of_record.year
    @person = Person.find(params[:person_id])
    @family = Family.find(params[:family_id])
    @hbx = HbxEnrollment.find(params[:hbx_enrollment_id]) if params[:hbx_enrollment_id].present?
    @hbxs = @family.active_household.hbx_enrollments_with_aptc_by_year(@current_year)
    @household_info = HbxAdmin.build_household_level_aptc_csr_data(@family, @hbxs, params[:max_aptc].to_f, params[:csr_percentage].to_i, params[:applied_aptcs_array])
    @enrollments_info = HbxAdmin.build_enrollments_data(@family, @hbxs, params[:applied_aptcs_array], params[:max_aptc].to_f, params[:csr_percentage].to_i, params[:memeber_ids])
    @slcsp_value = HbxAdmin.calculate_slcsp_value(@family)
    @household_members = HbxAdmin.build_household_members(@family)
    @current_aptc_applied_hash =  HbxAdmin.build_current_aptc_applied_hash(@hbxs, params[:applied_aptcs_array])
    @aptc_applied_for_all_hbxs = @family.active_household.hbx_enrollments_with_aptc_by_year(@current_year).map{|h| h.applied_aptc_amount.to_f}.sum || 0
    @plan_premium_for_enrollments = HbxAdmin.build_plan_premium_hash_for_enrollments(@hbxs)
    @active_tax_household_for_current_year = @family.active_household.latest_active_tax_household_with_year(@current_year)
    @max_aptc = ( params[:max_aptc]=="NaN" ? params[:max_aptc] : '%.2f' % params[:max_aptc] ) || @family.active_household.latest_active_tax_household.latest_eligibility_determination.max_aptc    
    @csr_percent_as_integer = params[:csr_percentage] || @family.active_household.latest_active_tax_household.latest_eligibility_determination.csr_percent_as_integer
    
    respond_to do |format|
      format.js { render (@hbxs.blank? ? "edit_aptc_csr_no_enrollment" : "edit_aptc_csr_active_enrollment")} if @aptc_errors.blank?
      format.js { render "household_header"} if @aptc_errors.present?
    end
  end

end